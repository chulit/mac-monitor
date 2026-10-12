import Foundation

public enum Availability: Sendable, Equatable, Codable {
  case available
  case unavailable
}

public struct Sample: Sendable, Equatable, Codable {
  public let timestamp: Date
  public let availability: Availability
  public let value: Double?
  public let metric: String

  public init(timestamp: Date, availability: Availability, value: Double? = nil, metric: String = "cpu") {
    self.timestamp = timestamp
    self.availability = availability
    self.value = value
    self.metric = metric
  }
}
