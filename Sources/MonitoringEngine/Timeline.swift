import Foundation

public struct TimelineMarker: Sendable, Equatable, Codable {
  public enum Kind: String, Sendable, Equatable, Codable {
    case started
    case peak
    case recovered
  }

  public let timestamp: Date
  public let kind: Kind

  public init(timestamp: Date, kind: Kind) {
    self.timestamp = timestamp
    self.kind = kind
  }
}

public struct IncidentTimeline: Sendable, Equatable, Codable {
  public let incident: Incident
  public let metricSamples: [Sample]
  public let gaps: [Gap]
  public let markers: [TimelineMarker]
  public let ruleVersion: String?
  public let baselineVersion: String?
  public let relevantProcesses: [ProcessRelevance]
  public let observationTransitions: [ObservationTransition]

  public init(
    incident: Incident,
    metricSamples: [Sample],
    gaps: [Gap],
    markers: [TimelineMarker],
    ruleVersion: String?,
    baselineVersion: String?,
    relevantProcesses: [ProcessRelevance],
    observationTransitions: [ObservationTransition] = []
  ) {
    self.incident = incident
    self.metricSamples = metricSamples
    self.gaps = gaps
    self.markers = markers
    self.ruleVersion = ruleVersion
    self.baselineVersion = baselineVersion
    self.relevantProcesses = relevantProcesses
    self.observationTransitions = observationTransitions
  }
}
