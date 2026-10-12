import Foundation

public struct BaselineConfig: Sendable, Equatable {
  public let promotionSamples: Int
  public let maturitySamples: Int
  public let deviationThreshold: Double
  public let triggerDuration: TimeInterval
  public let recoveryDuration: TimeInterval
  public let cooldown: TimeInterval
  public let stalenessWindow: TimeInterval
  public let algorithmVersion: String

  public init(
    promotionSamples: Int,
    maturitySamples: Int,
    deviationThreshold: Double,
    triggerDuration: TimeInterval,
    recoveryDuration: TimeInterval,
    cooldown: TimeInterval,
    stalenessWindow: TimeInterval,
    algorithmVersion: String
  ) {
    self.promotionSamples = promotionSamples
    self.maturitySamples = maturitySamples
    self.deviationThreshold = deviationThreshold
    self.triggerDuration = triggerDuration
    self.recoveryDuration = recoveryDuration
    self.cooldown = cooldown
    self.stalenessWindow = stalenessWindow
    self.algorithmVersion = algorithmVersion
  }
}

public struct Baseline: Sendable {
  public enum Status: String, Sendable, Equatable {
    case learning
    case limited
    case stable
    case stale
  }

  public struct Change: Sendable, Equatable {
    public let time: Date
    public let reason: String
    public let algorithmVersion: String
    public let qualifyingSamples: Int

    public init(time: Date, reason: String, algorithmVersion: String, qualifyingSamples: Int) {
      self.time = time
      self.reason = reason
      self.algorithmVersion = algorithmVersion
      self.qualifyingSamples = qualifyingSamples
    }
  }

  public private(set) var status: Status = .learning
  public private(set) var history: [Change] = []
  public private(set) var qualifyingSamples: Int = 0

  public var mean: Double {
    qualifyingSamples > 0 ? runningMean : 0
  }

  public var isActive: Bool {
    activeSince != nil
  }

  private let config: BaselineConfig
  private var runningMean = 0.0
  private var m2 = 0.0
  private var activeSince: Date?
  private var lastLearnedAt: Date?

  public init(config: BaselineConfig) {
    self.config = config
  }

  public mutating func learn(_ samples: [Sample], excluding incidents: [Incident], now: Date) {
    var learned = false
    for sample in samples where sample.availability == .available {
      guard let value = sample.value, !insideIncident(sample.timestamp, incidents) else {
        continue
      }
      qualifyingSamples += 1
      let delta = value - runningMean
      runningMean += delta / Double(qualifyingSamples)
      m2 += delta * (value - runningMean)
      learned = true
      if activeSince == nil && qualifyingSamples >= config.promotionSamples {
        activeSince = now
        history.append(
          Change(
            time: now,
            reason: "promoted to active",
            algorithmVersion: config.algorithmVersion,
            qualifyingSamples: qualifyingSamples
          )
        )
      }
    }
    if learned {
      lastLearnedAt = now
    }
    updateStatus(now: now)
  }

  public func deviation(of value: Double) -> Double? {
    guard isActive, qualifyingSamples >= 2 else {
      return nil
    }
    let variance = m2 / Double(qualifyingSamples - 1)
    let spread = variance.squareRoot()
    if spread == 0 {
      return value == runningMean ? 0 : .infinity
    }
    return abs(value - runningMean) / spread
  }

  public var detectionRule: TechnicalRule {
    TechnicalRule(
      threshold: config.deviationThreshold,
      triggerDuration: config.triggerDuration,
      recoveryDuration: config.recoveryDuration,
      cooldown: config.cooldown
    )
  }

  public func deviationStream(for samples: [Sample], excluding incidents: [Incident]) -> [Sample] {
    guard isActive else {
      return []
    }
    return samples.map { sample in
      guard sample.availability == .available,
        let value = sample.value,
        !insideIncident(sample.timestamp, incidents),
        let magnitude = deviation(of: value)
      else {
        return Sample(timestamp: sample.timestamp, availability: .unavailable, value: nil)
      }
      return Sample(timestamp: sample.timestamp, availability: .available, value: magnitude)
    }
  }

  private mutating func updateStatus(now: Date) {
    guard activeSince != nil else {
      status = .learning
      return
    }
    if let last = lastLearnedAt,
      now.timeIntervalSince(last) > config.stalenessWindow
    {
      status = .stale
      return
    }
    status = qualifyingSamples >= config.maturitySamples ? .stable : .limited
  }

  private func insideIncident(_ timestamp: Date, _ incidents: [Incident]) -> Bool {
    incidents.contains { incident in
      timestamp >= incident.startedAt
        && timestamp < (incident.recoveredAt ?? .distantFuture)
    }
  }
}
