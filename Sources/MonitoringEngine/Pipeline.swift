import Foundation

public struct Incident: Sendable, Equatable, Codable, Hashable {
  public enum Source: Sendable, Equatable, Hashable {
    case rule(version: String)
    case baseline(version: String)
  }

  public let startedAt: Date
  public let peakAt: Date
  public let recoveredAt: Date?
  public let source: Source

  public init(startedAt: Date, peakAt: Date, recoveredAt: Date?, source: Source) {
    self.startedAt = startedAt
    self.peakAt = peakAt
    self.recoveredAt = recoveredAt
    self.source = source
  }
}

public struct Gap: Sendable, Equatable, Codable {
  public let timestamp: Date

  public init(timestamp: Date) {
    self.timestamp = timestamp
  }
}

public struct Evaluation: Sendable, Equatable {
  public let incidents: [Incident]
  public let gaps: [Gap]
  public let timelines: [IncidentTimeline]
  public let observation: Observation?
  public let observationTransitions: [ObservationTransition]

  public init(
    incidents: [Incident],
    gaps: [Gap],
    timelines: [IncidentTimeline],
    observation: Observation? = nil,
    observationTransitions: [ObservationTransition] = []
  ) {
    self.incidents = incidents
    self.gaps = gaps
    self.timelines = timelines
    self.observation = observation
    self.observationTransitions = observationTransitions
  }
}

public final class Pipeline<C: Clock> {
  private let clock: C
  private var rules: [TechnicalRule]
  private let baselineConfig: BaselineConfig?
  private var observationPolicy: ObservationPolicy?
  private let retentionPolicy: RetentionPolicy?
  private var historyStore: HistoryStore?
  private var historyRecording = HistoryRecording.metricsAndIncidents
  public private(set) var baselines: [String: Baseline] = [:]
  private var observationState: ObservationState?
  private var observationHistory: [ObservationTransition] = []
  private var pendingObservationTransitions: [ObservationTransition] = []
  private var historyStore: HistoryStore?

  public init(
    clock: C,
    rules: [TechnicalRule] = [],
    baseline config: BaselineConfig? = nil,
    observation policy: ObservationPolicy? = nil,
    retention retentionPolicy: RetentionPolicy? = nil
  ) {
    self.clock = clock
    self.rules = rules
    self.baselineConfig = config
    self.observationPolicy = policy
    self.retentionPolicy = retentionPolicy
    if policy != nil {
      self.observationState = ObservationState()
    }
    if let retentionPolicy {
      self.historyStore = HistoryStore(policy: retentionPolicy)
    }
  }

  public var history: HistorySnapshot? {
    historyStore?.snapshot()
  }

  public func pin(_ incident: Incident) {
    historyStore?.pin(incident)
  }

  /// Which parts of the retention store stay enabled. Driven by the
  /// Data & Storage settings; the in-memory evaluation is unaffected.
  public struct HistoryRecording: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) {
      self.rawValue = rawValue
    }

    public static let metrics = HistoryRecording(rawValue: 1 << 0)
    public static let incidents = HistoryRecording(rawValue: 1 << 1)
    public static let metricsAndIncidents: HistoryRecording = [.metrics, .incidents]
  }

  public func setHistoryRecording(_ recording: HistoryRecording) {
    historyRecording = recording
  }

  /// Replaces the rule thresholds in place (Settings → Alert Thresholds).
  /// Baselines, history, and observation state are preserved; only rules
  /// whose single scoped metric has a new threshold are rebuilt.
  public func updateRuleThresholds(_ thresholds: [String: Double]) {
    rules = rules.map { rule in
      guard let metrics = rule.metrics, metrics.count == 1,
        let metric = metrics.first, let threshold = thresholds[metric]
      else {
        return rule
      }
      return TechnicalRule(
        threshold: threshold,
        triggerDuration: rule.triggerDuration,
        recoveryDuration: rule.recoveryDuration,
        cooldown: rule.cooldown,
        version: rule.version,
        metrics: rule.metrics
      )
    }
  }

  /// Live retention change (Settings → Data Retention). The new cutoff
  /// applies on the next recorded batch; older data compacts then.
  public func updateRetention(detailRetention: TimeInterval) {
    historyStore?.updatePolicy(
      RetentionPolicy(
        detailRetention: detailRetention,
        quota: retentionPolicy?.quota ?? 150_000_000,
        thresholdsByMetric: retentionPolicy?.thresholdsByMetric ?? [:]
      )
    )
  }

  /// Live observation budget change (Settings → Max CPU Usage).
  public func updateBudgetLimit(_ limit: Double) {
    guard var policy = observationPolicy else {
      return
    }
    policy = ObservationPolicy(
      budgetLimit: limit,
      criticalMetrics: policy.criticalMetrics,
      normalInterval: policy.normalInterval,
      reducedInterval: policy.reducedInterval,
      highDetailInterval: policy.highDetailInterval,
      overBudgetEvaluationsToDegrade: policy.overBudgetEvaluationsToDegrade,
      underBudgetEvaluationsToRecover: policy.underBudgetEvaluationsToRecover,
      maximumHighDetailDuration: policy.maximumHighDetailDuration,
      highDetailWarningBeforeEnd: policy.highDetailWarningBeforeEnd
    )
    observationPolicy = policy
  }

  /// Live critical-metrics change (Settings → Monitored Metrics). A metric
  /// the user disabled stops being exempt from observation degradation.
  public func updateCriticalMetrics(_ metrics: Set<String>) {
    guard var policy = observationPolicy else {
      return
    }
    policy = ObservationPolicy(
      budgetLimit: policy.budgetLimit,
      criticalMetrics: metrics,
      normalInterval: policy.normalInterval,
      reducedInterval: policy.reducedInterval,
      highDetailInterval: policy.highDetailInterval,
      overBudgetEvaluationsToDegrade: policy.overBudgetEvaluationsToDegrade,
      underBudgetEvaluationsToRecover: policy.underBudgetEvaluationsToRecover,
      maximumHighDetailDuration: policy.maximumHighDetailDuration,
      highDetailWarningBeforeEnd: policy.highDetailWarningBeforeEnd
    )
    observationPolicy = policy
  }

  /// Drops all recorded history (Settings → Clear History). Live
  /// baselines and the current evaluation are untouched.
  public func clearHistory() {
    guard let policy = retentionPolicy else {
      return
    }
    historyStore = HistoryStore(policy: policy)
  }

  public func baseline(for metric: String) -> Baseline? {
    baselines[metric]
  }

  public func requestHighDetail(duration: TimeInterval) {
    guard let policy = observationPolicy, var state = observationState else {
      return
    }
    let now = clock.now()
    if let endsAt = state.highDetailEndsAt, now < endsAt {
      return
    }
    let limit = min(duration, policy.maximumHighDetailDuration)
    state.highDetailEndsAt = now.addingTimeInterval(limit)
    state.highDetailLimit = limit
    state.highDetailWarned = false
    state.overBudgetStreak = 0
    state.underBudgetStreak = 0
    let transition = ObservationTransition(
      timestamp: now,
      from: state.coarse,
      to: .highDetail,
      reason: "high-detail session started",
      affectedMetrics: []
    )
    state.coarse = .highDetail
    observationState = state
    observationHistory.append(transition)
    pendingObservationTransitions.append(transition)
  }

  /// Ends a high-detail session early, as when the user taps Stop Investigation.
  /// A no-op when no session is active. Mirrors the natural expiry path so the
  /// timeline reads the same whether the session timed out or was stopped.
  public func endHighDetail() {
    guard var state = observationState else {
      return
    }
    guard state.coarse == .highDetail, state.highDetailEndsAt != nil else {
      return
    }
    let now = clock.now()
    state.coarse = .normal
    state.highDetailEndsAt = nil
    state.highDetailLimit = nil
    state.highDetailWarned = false
    state.overBudgetStreak = 0
    state.underBudgetStreak = 0
    let transition = ObservationTransition(
      timestamp: now,
      from: .highDetail,
      to: .normal,
      reason: "high-detail session ended early",
      affectedMetrics: []
    )
    observationState = state
    observationHistory.append(transition)
    pendingObservationTransitions.append(transition)
  }

  public func evaluate(
    _ samples: [Sample],
    processes: [ProcessSample] = [],
    usage: ResourceUsage? = nil
  ) -> Evaluation {
    let gaps = samples
      .filter { $0.availability == .unavailable }
      .map { Gap(timestamp: $0.timestamp) }
    let ruleIncidents = rules.flatMap { rule in
      let scoped =
        rule.metrics.map { allowed in samples.filter { allowed.contains($0.metric) } }
        ?? samples
      return incidents(matching: rule, in: scoped, source: .rule(version: rule.version))
    }
    var deviationIncidents: [Incident] = []
    let metrics = Set(samples.map(\.metric)).union(baselines.keys).sorted()
    if baselineConfig != nil {
      for metric in metrics {
        guard let baseline = baselines[metric], baseline.isActive else {
          continue
        }
        let group = samples.filter { $0.metric == metric }
        let transformed = baseline.deviationStream(for: group, excluding: ruleIncidents)
        deviationIncidents += incidents(
          matching: baseline.detectionRule,
          in: transformed,
          source: .baseline(version: baseline.algorithmVersion)
        )
      }
    }
    let incidents = ruleIncidents + deviationIncidents
    if retentionPolicy != nil {
      let keptSamples = historyRecording.contains(.metrics) ? samples : []
      let keptIncidents = historyRecording.contains(.incidents) ? incidents : []
      historyStore?.record(samples: keptSamples, incidents: keptIncidents, now: clock.now())
    }
    if let config = baselineConfig {
      for metric in metrics {
        var baseline = baselines[metric] ?? Baseline(config: config)
        baseline.learn(
          samples.filter { $0.metric == metric },
          excluding: incidents,
          now: clock.now()
        )
        baselines[metric] = baseline
      }
    }
    var newObservationTransitions: [ObservationTransition] = []
    let observation = currentObservation(
      samples: samples,
      usage: usage,
      newTransitions: &newObservationTransitions
    )
    let timelines = incidents.map {
      timeline(
        for: $0,
        samples: samples,
        gaps: gaps,
        processes: processes,
        observationHistory: observationHistory
      )
    }
    return Evaluation(
      incidents: incidents,
      gaps: gaps,
      timelines: timelines,
      observation: observation,
      observationTransitions: newObservationTransitions
    )
  }

  private func currentObservation(
    samples: [Sample],
    usage: ResourceUsage?,
    newTransitions: inout [ObservationTransition]
  ) -> Observation? {
    guard let policy = observationPolicy, var state = observationState else {
      return nil
    }
    let now = clock.now()
    let observedMetrics = Set(samples.map(\.metric)).sorted()
    newTransitions += pendingObservationTransitions
    pendingObservationTransitions = []
    if state.coarse == .highDetail {
      if let endsAt = state.highDetailEndsAt, state.highDetailLimit != nil {
        if now >= endsAt {
          state.coarse = .normal
          state.highDetailEndsAt = nil
          state.highDetailLimit = nil
          state.highDetailWarned = false
          state.overBudgetStreak = 0
          state.underBudgetStreak = 0
          let transition = ObservationTransition(
            timestamp: now,
            from: .highDetail,
            to: .normal,
            reason: "high-detail session ended",
            affectedMetrics: []
          )
          observationHistory.append(transition)
          newTransitions.append(transition)
        } else if !state.highDetailWarned,
          endsAt.timeIntervalSince(now) <= policy.highDetailWarningBeforeEnd
        {
          state.highDetailWarned = true
          let transition = ObservationTransition(
            timestamp: now,
            from: .highDetail,
            to: .highDetail,
            reason: "high-detail session ending soon",
            affectedMetrics: []
          )
          observationHistory.append(transition)
          newTransitions.append(transition)
        }
      } else {
        state.coarse = .normal
      }
    }
    if state.coarse != .highDetail, let usage {
      if usage.used > policy.budgetLimit {
        state.overBudgetStreak += 1
        state.underBudgetStreak = 0
        if state.coarse == .normal
          && state.overBudgetStreak >= policy.overBudgetEvaluationsToDegrade
        {
          state.coarse = .reduced
          let affected = observedMetrics.filter { !policy.criticalMetrics.contains($0) }
          let transition = ObservationTransition(
            timestamp: now,
            from: .normal,
            to: .reduced,
            reason: "over resource budget",
            affectedMetrics: affected
          )
          observationHistory.append(transition)
          newTransitions.append(transition)
        }
      } else {
        state.underBudgetStreak += 1
        state.overBudgetStreak = 0
        if state.coarse == .reduced
          && state.underBudgetStreak >= policy.underBudgetEvaluationsToRecover
        {
          state.coarse = .normal
          let transition = ObservationTransition(
            timestamp: now,
            from: .reduced,
            to: .normal,
            reason: "within resource budget",
            affectedMetrics: []
          )
          observationHistory.append(transition)
          newTransitions.append(transition)
        }
      }
    }
    observationState = state
    let mode: ObservationMode
    let intervals: [String: TimeInterval]
    switch state.coarse {
    case .normal:
      mode = .normal
      intervals = Dictionary(
        uniqueKeysWithValues: observedMetrics.map { ($0, policy.normalInterval) }
      )
    case .reduced:
      let affected = observedMetrics.filter { !policy.criticalMetrics.contains($0) }
      mode = .reduced(reason: "over resource budget", affectedMetrics: affected)
      intervals = Dictionary(
        uniqueKeysWithValues: observedMetrics.map {
          ($0, policy.criticalMetrics.contains($0) ? policy.normalInterval : policy.reducedInterval)
        }
      )
    case .highDetail:
      if let endsAt = state.highDetailEndsAt,
        let limit = state.highDetailLimit,
        now < endsAt
      {
        mode = .highDetail(
          remaining: endsAt.timeIntervalSince(now),
          limit: limit,
          warning: state.highDetailWarned
        )
      } else {
        mode = .normal
      }
      intervals = Dictionary(
        uniqueKeysWithValues: observedMetrics.map { ($0, policy.highDetailInterval) }
      )
    }
    let times = Set(samples.map(\.timestamp)).sorted()
    let observed = Array(
      Set(zip(times, times.dropFirst()).map { $1.timeIntervalSince($0) })
    ).sorted()
    return Observation(mode: mode, intervalsByMetric: intervals, observedIntervals: observed)
  }

  private func timeline(
    for incident: Incident,
    samples: [Sample],
    gaps: [Gap],
    processes: [ProcessSample],
    observationHistory: [ObservationTransition]
  ) -> IncidentTimeline {
    let end = incident.recoveredAt ?? samples.map(\.timestamp).max() ?? incident.startedAt
    let inSpan = { (timestamp: Date) in
      timestamp >= incident.startedAt && timestamp <= end
    }
    let metricSamples = samples.filter {
      $0.availability == .available && inSpan($0.timestamp)
    }
    let spanGaps = gaps.filter { inSpan($0.timestamp) }
    var markers = [
      TimelineMarker(timestamp: incident.startedAt, kind: .started),
      TimelineMarker(timestamp: incident.peakAt, kind: .peak),
    ]
    if let recoveredAt = incident.recoveredAt {
      markers.append(TimelineMarker(timestamp: recoveredAt, kind: .recovered))
    }
    let ruleVersion: String?
    let baselineVersion: String?
    switch incident.source {
    case .rule(let version):
      ruleVersion = version
      baselineVersion = nil
    case .baseline(let version):
      ruleVersion = nil
      baselineVersion = version
    }
    return IncidentTimeline(
      incident: incident,
      metricSamples: metricSamples,
      gaps: spanGaps,
      markers: markers,
      ruleVersion: ruleVersion,
      baselineVersion: baselineVersion,
      relevantProcesses: rankRelevance(processes: processes, from: incident.startedAt, through: end),
      observationTransitions: observationHistory.filter {
        $0.timestamp >= incident.startedAt && $0.timestamp <= end
      }
    )
  }

  private func incidents(
    matching rule: TechnicalRule,
    in samples: [Sample],
    source: Incident.Source
  ) -> [Incident] {
    var found: [Incident] = []
    var excursionStart: Date?
    var peakTime: Date?
    var peakValue = -Double.infinity
    var normalRunStart: Date?
    var openStart: Date?
    var lastRecovery: Date?
    var suppressed = false

    for sample in samples {
      guard sample.availability == .available, let value = sample.value else {
        excursionStart = nil
        normalRunStart = nil
        continue
      }
      if value >= rule.threshold {
        normalRunStart = nil
        if excursionStart == nil {
          excursionStart = sample.timestamp
          peakTime = sample.timestamp
          peakValue = value
          if let last = lastRecovery,
            sample.timestamp.timeIntervalSince(last) < rule.cooldown
          {
            suppressed = true
          }
        } else if value > peakValue {
          peakTime = sample.timestamp
          peakValue = value
        }
        if !suppressed, openStart == nil, let start = excursionStart,
          sample.timestamp.timeIntervalSince(start) >= rule.triggerDuration
        {
          openStart = start
        }
      } else if openStart != nil {
        if normalRunStart == nil {
          normalRunStart = sample.timestamp
        }
        if let runStart = normalRunStart,
          sample.timestamp.timeIntervalSince(runStart) >= rule.recoveryDuration,
          let start = openStart, let peak = peakTime
        {
          found.append(Incident(startedAt: start, peakAt: peak, recoveredAt: runStart, source: source))
          lastRecovery = runStart
          openStart = nil
          excursionStart = nil
          normalRunStart = nil
        }
      } else {
        excursionStart = nil
        suppressed = false
      }
    }

    if let start = openStart, let peak = peakTime {
      found.append(Incident(startedAt: start, peakAt: peak, recoveredAt: nil, source: source))
    }
    return found
  }
}
