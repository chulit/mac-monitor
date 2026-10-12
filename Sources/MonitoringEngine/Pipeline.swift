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

  public init(incidents: [Incident], gaps: [Gap], timelines: [IncidentTimeline]) {
    self.incidents = incidents
    self.gaps = gaps
    self.timelines = timelines
  }
}

public final class Pipeline<C: Clock> {
  private let clock: C
  private let rules: [TechnicalRule]
  private let baselineConfig: BaselineConfig?
  public private(set) var baselines: [String: Baseline] = [:]

  public init(clock: C, rules: [TechnicalRule] = [], baseline config: BaselineConfig? = nil) {
    self.clock = clock
    self.rules = rules
    self.baselineConfig = config
  }

  public func baseline(for metric: String) -> Baseline? {
    baselines[metric]
  }

  public func evaluate(_ samples: [Sample], processes: [ProcessSample] = []) -> Evaluation {
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
    let timelines = incidents.map {
      timeline(for: $0, samples: samples, gaps: gaps, processes: processes)
    }
    return Evaluation(incidents: incidents, gaps: gaps, timelines: timelines)
  }

  private func timeline(
    for incident: Incident,
    samples: [Sample],
    gaps: [Gap],
    processes: [ProcessSample]
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
      relevantProcesses: rankRelevance(processes: processes, from: incident.startedAt, through: end)
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
