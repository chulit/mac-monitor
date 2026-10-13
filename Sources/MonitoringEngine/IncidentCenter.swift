import Foundation

/// Status filter for the incidents list.
public enum IncidentStatusFilter: String, Sendable, Equatable, CaseIterable {
  case all = "All"
  case active = "Active"
  case resolved = "Resolved"
}

/// Date range filter for the incidents list.
public enum IncidentDateRange: String, Sendable, Equatable, CaseIterable {
  case day = "Last 24 Hours"
  case week = "Last 7 Days"
  case month = "Last 30 Days"

  public var seconds: TimeInterval {
    switch self {
    case .day: return 86_400
    case .week: return 604_800
    case .month: return 2_592_000
    }
  }
}

/// Newest-first incidents matching the status and date-range filters.
public func filteredIncidents(
  _ incidents: [Incident],
  status: IncidentStatusFilter,
  range: IncidentDateRange,
  now: Date
) -> [Incident] {
  let cutoff = now.addingTimeInterval(-range.seconds)
  return incidents
    .filter { incident in
      guard incident.startedAt >= cutoff else {
        return false
      }
      switch status {
      case .all:
        return true
      case .active:
        return incident.recoveredAt == nil
      case .resolved:
        return incident.recoveredAt != nil
      }
    }
    .sorted { $0.startedAt > $1.startedAt }
}

/// Compact duration rendering: "45s", "3m 24s", "2h 5m".
public func formatDuration(_ interval: TimeInterval) -> String {
  let total = max(Int(interval.rounded()), 0)
  let hours = total / 3600
  let minutes = (total % 3600) / 60
  let seconds = total % 60
  if hours > 0 {
    return "\(hours)h \(minutes)m"
  }
  if minutes > 0 {
    return "\(minutes)m \(seconds)s"
  }
  return "\(seconds)s"
}

public struct IncidentSummary: Sendable, Equatable {
  public let primaryMetric: String?
  /// Peak sample value for the primary metric; nil without samples.
  public let peak: Double?
  /// Mean sample value for the primary metric; nil without samples.
  public let average: Double?
  public let isOngoing: Bool
  public let affectedProcesses: Int

  public init(
    primaryMetric: String?,
    peak: Double?,
    average: Double?,
    isOngoing: Bool,
    affectedProcesses: Int
  ) {
    self.primaryMetric = primaryMetric
    self.peak = peak
    self.average = average
    self.isOngoing = isOngoing
    self.affectedProcesses = affectedProcesses
  }
}

/// Summary statistics for the detail pane, computed from the timeline's own
/// samples. A missing timeline (or no samples) yields nils, never zeros.
public func incidentSummary(
  incident: Incident,
  timeline: IncidentTimeline?
) -> IncidentSummary {
  let samples = timeline?.metricSamples ?? []
  let primaryMetric = samples.first?.metric
  let values = samples.compactMap(\.value)
  let peak = values.max()
  let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
  return IncidentSummary(
    primaryMetric: primaryMetric,
    peak: peak,
    average: average,
    isOngoing: incident.recoveredAt == nil,
    affectedProcesses: timeline?.relevantProcesses.count ?? 0
  )
}

public struct IncidentEvent: Sendable, Equatable, Hashable {
  public enum Kind: Sendable, Equatable, Hashable {
    case detected
    case peak
    case note
    case recovered
    case ongoing
  }

  public let timestamp: Date
  public let kind: Kind
  public let text: String

  public init(timestamp: Date, kind: Kind, text: String) {
    self.timestamp = timestamp
    self.kind = kind
    self.text = text
  }
}

/// Chronological event trail built only from timestamped engine records:
/// lifecycle markers and observation transitions. Process attribution has
/// no per-event timestamps, so it lives in the Related Processes table
/// instead of being invented here.
public func incidentEvents(
  incident: Incident,
  timeline: IncidentTimeline?,
  now: Date
) -> [IncidentEvent] {
  var events: [IncidentEvent] = []
  let title = incidentTitle(
    incident: incident,
    metric: timeline?.metricSamples.first?.metric
  )
  for marker in timeline?.markers ?? [] {
    switch marker.kind {
    case .started:
      events.append(IncidentEvent(
        timestamp: marker.timestamp,
        kind: .detected,
        text: "\(title) detected"
      ))
    case .peak:
      if let peak = timeline?.metricSamples.compactMap(\.value).max() {
        let metric = timeline?.metricSamples.first?.metric ?? "metric"
        events.append(IncidentEvent(
          timestamp: marker.timestamp,
          kind: .peak,
          text: "Peak \(metric) \(formatPercent(peak))"
        ))
      }
    case .recovered:
      events.append(IncidentEvent(
        timestamp: marker.timestamp,
        kind: .recovered,
        text: "\(title) recovered"
      ))
    }
  }
  for transition in timeline?.observationTransitions ?? [] {
    events.append(IncidentEvent(
      timestamp: transition.timestamp,
      kind: .note,
      text: transition.reason
    ))
  }
  if incident.recoveredAt == nil {
    events.append(IncidentEvent(
      timestamp: now,
      kind: .ongoing,
      text: "Still ongoing…"
    ))
  }
  return events.sorted { $0.timestamp < $1.timestamp }
}

private func formatPercent(_ value: Double) -> String {
  String(format: "%.0f%%", value * 100)
}
