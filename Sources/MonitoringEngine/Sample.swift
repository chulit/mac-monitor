import Foundation

public enum Availability: Sendable, Equatable {
  case available
  case unavailable
}

public struct Sample: Sendable, Equatable {
  public let timestamp: Date
  public let availability: Availability
  public let value: Double?

  public init(timestamp: Date, availability: Availability, value: Double? = nil) {
    self.timestamp = timestamp
    self.availability = availability
    self.value = value
  }
}
