import Foundation

public struct Incident: Sendable, Equatable {
  public enum Source: Sendable, Equatable {
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

public struct Gap: Sendable, Equatable {
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
  private let rules: [TechnicalRule]
  private let baselineConfig: BaselineConfig?
  private let observationPolicy: ObservationPolicy?
  public private(set) var baselines: [String: Baseline] = [:]
  private var observationState: ObservationState?
  private var observationHistory: [ObservationTransition] = []
  private var pendingObservationTransitions: [ObservationTransition] = []

  public init(
    clock: C,
    rules: [TechnicalRule] = [],
    baseline config: BaselineConfig? = nil,
    observation policy: ObservationPolicy? = nil
  ) {
    self.clock = clock
    self.rules = rules
    self.baselineConfig = config
    self.observationPolicy = policy
    if policy != nil {
      self.observationState = ObservationState()
    }
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

  public func evaluate(
    _ samples: [Sample],
    processes: [ProcessSample] = [],
    usage: ResourceUsage? = nil
  ) -> Evaluation {
    let gaps = samples
      .filter { $0.availability == .unavailable }
      .map { Gap(timestamp: $0.timestamp) }
    let ruleIncidents = rules.flatMap {
      incidents(matching: $0, in: samples, source: .rule(version: $0.version))
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
