import Foundation

public protocol Clock {
  func now() -> Date
}

public final class ControlledClock: Clock {
  private var start: Date

  public init(startingAt start: Date) {
    self.start = start
  }

  public func now() -> Date {
    start
  }

  public func advance(by interval: TimeInterval) {
    start = start.addingTimeInterval(interval)
  }
}
