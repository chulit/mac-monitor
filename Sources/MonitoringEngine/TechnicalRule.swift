import Foundation

public struct TechnicalRule: Sendable, Equatable {
  public let threshold: Double
  public let triggerDuration: TimeInterval
  public let recoveryDuration: TimeInterval
  public let cooldown: TimeInterval

  public init(
    threshold: Double,
    triggerDuration: TimeInterval,
    recoveryDuration: TimeInterval,
    cooldown: TimeInterval
  ) {
    self.threshold = threshold
    self.triggerDuration = triggerDuration
    self.recoveryDuration = recoveryDuration
    self.cooldown = cooldown
  }
}
