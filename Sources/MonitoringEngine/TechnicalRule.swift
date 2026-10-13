import Foundation

public struct TechnicalRule: Sendable, Equatable {
  public let threshold: Double
  public let triggerDuration: TimeInterval
  public let recoveryDuration: TimeInterval
  public let cooldown: TimeInterval
  public let version: String
  public let metrics: Set<String>?

  public init(
    threshold: Double,
    triggerDuration: TimeInterval,
    recoveryDuration: TimeInterval,
    cooldown: TimeInterval,
    version: String = "1",
    metrics: Set<String>? = nil
  ) {
    self.threshold = threshold
    self.triggerDuration = triggerDuration
    self.recoveryDuration = recoveryDuration
    self.cooldown = cooldown
    self.version = version
    self.metrics = metrics
  }
}
