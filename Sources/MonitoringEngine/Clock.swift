import Foundation

public protocol Clock: Sendable {
  func now() -> Date
}

public struct ControlledClock: Clock, Sendable {
  private let start: Date

  public init(startingAt start: Date) {
    self.start = start
  }

  public func now() -> Date {
    start
  }
}
