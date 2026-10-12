import Foundation

public struct Incident: Sendable, Equatable {
  public let startedAt: Date
  public let peakAt: Date
  public let recoveredAt: Date?

  public init(startedAt: Date, peakAt: Date, recoveredAt: Date?) {
    self.startedAt = startedAt
    self.peakAt = peakAt
    self.recoveredAt = recoveredAt
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

  public init(incidents: [Incident], gaps: [Gap]) {
    self.incidents = incidents
    self.gaps = gaps
  }
}

public final class Pipeline<C: Clock> {
  private let clock: C
  private let rules: [TechnicalRule]
  public private(set) var baseline: Baseline?

  public init(clock: C, rules: [TechnicalRule] = [], baseline config: BaselineConfig? = nil) {
    self.clock = clock
    self.rules = rules
    self.baseline = config.map(Baseline.init(config:))
  }

  public func evaluate(_ samples: [Sample]) -> Evaluation {
    let gaps = samples
      .filter { $0.availability == .unavailable }
      .map { Gap(timestamp: $0.timestamp) }
    let ruleIncidents = rules.flatMap { incidents(matching: $0, in: samples) }
    var deviationIncidents: [Incident] = []
    if let baseline {
      let transformed = baseline.deviationStream(for: samples, excluding: ruleIncidents)
      deviationIncidents = incidents(matching: baseline.detectionRule, in: transformed)
    }
    let incidents = ruleIncidents + deviationIncidents
    baseline?.learn(samples, excluding: incidents, now: clock.now())
    return Evaluation(incidents: incidents, gaps: gaps)
  }

  private func incidents(matching rule: TechnicalRule, in samples: [Sample]) -> [Incident] {
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
          found.append(Incident(startedAt: start, peakAt: peak, recoveredAt: runStart))
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
      found.append(Incident(startedAt: start, peakAt: peak, recoveredAt: nil))
    }
    return found
  }
}
