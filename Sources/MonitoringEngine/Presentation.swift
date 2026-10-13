import Foundation

public enum DashboardDetail: Sendable, Equatable {
  case summary
  case detailed
}

public enum SystemHealth: String, Sendable, Equatable {
  case unknown
}

public struct DashboardIncident: Sendable, Equatable {
  public let startedAt: Date
  public let recoveredAt: Date?
  public let relevantProcessCount: Int

  public var isActive: Bool {
    recoveredAt == nil
  }

  public init(startedAt: Date, recoveredAt: Date?, relevantProcessCount: Int) {
    self.startedAt = startedAt
    self.recoveredAt = recoveredAt
    self.relevantProcessCount = relevantProcessCount
  }
}

public struct MonitoringStatus: Sendable, Equatable {
  public let headline: String
  public let detail: String?

  public init(headline: String, detail: String? = nil) {
    self.headline = headline
    self.detail = detail
  }
}

public struct DashboardSnapshot: Sendable, Equatable {
  public let headline: String
  public let activeIncidentCount: Int
  public let totalIncidentCount: Int
  public let monitoring: MonitoringStatus
  public let systemHealth: SystemHealth
  public let incidents: [DashboardIncident]

  public init(
    headline: String,
    activeIncidentCount: Int,
    totalIncidentCount: Int,
    monitoring: MonitoringStatus,
    systemHealth: SystemHealth,
    incidents: [DashboardIncident]
  ) {
    self.headline = headline
    self.activeIncidentCount = activeIncidentCount
    self.totalIncidentCount = totalIncidentCount
    self.monitoring = monitoring
    self.systemHealth = systemHealth
    self.incidents = incidents
  }
}

public func makeDashboard(_ evaluation: Evaluation, detail: DashboardDetail = .summary) -> DashboardSnapshot {
  let active = evaluation.incidents.filter { $0.recoveredAt == nil }
  let headline =
    active.isEmpty ? "No active incidents"
    : active.count == 1 ? "1 active incident"
    : "\(active.count) active incidents"
  let incidents =
    detail == .detailed
    ? evaluation.incidents.map { incident in
      DashboardIncident(
        startedAt: incident.startedAt,
        recoveredAt: incident.recoveredAt,
        relevantProcessCount: evaluation.timelines.first { $0.incident == incident }?
          .relevantProcesses.count ?? 0
      )
    } : []
  return DashboardSnapshot(
    headline: headline,
    activeIncidentCount: active.count,
    totalIncidentCount: evaluation.incidents.count,
    monitoring: makeMonitoringStatus(evaluation.observation),
    systemHealth: .unknown,
    incidents: incidents
  )
}

public struct ProcessRow: Sendable, Equatable {
  public let process: Process
  public let depth: Int
  public let individualTotal: Double
  public let subtreeTotal: Double
  public let isExpanded: Bool
  public let hasChildren: Bool
  public let matchesQuery: Bool

  public init(
    process: Process,
    depth: Int,
    individualTotal: Double,
    subtreeTotal: Double,
    isExpanded: Bool,
    hasChildren: Bool,
    matchesQuery: Bool
  ) {
    self.process = process
    self.depth = depth
    self.individualTotal = individualTotal
    self.subtreeTotal = subtreeTotal
    self.isExpanded = isExpanded
    self.hasChildren = hasChildren
    self.matchesQuery = matchesQuery
  }
}

public func processRows(
  _ samples: [ProcessSample],
  query: String = "",
  expanded: Set<String> = []
) -> [ProcessRow] {
  var totals: [String: Double] = [:]
  var identities: [String: Process] = [:]
  for sample in samples {
    identities[sample.process.id] = sample.process
    totals[sample.process.id, default: 0] += sample.value
  }
  var children: [String: [String]] = [:]
  var roots: [String] = []
  for id in identities.keys.sorted() {
    if let parent = identities[id]?.parent, identities[parent] != nil {
      children[parent, default: []].append(id)
    } else {
      roots.append(id)
    }
  }
  var subtree: [String: Double] = [:]
  func subtreeTotal(_ id: String, _ path: Set<String>) -> Double {
    if let cached = subtree[id] {
      return cached
    }
    guard !path.contains(id) else {
      return totals[id] ?? 0
    }
    let total =
      (totals[id] ?? 0)
      + (children[id] ?? []).reduce(0) { $0 + subtreeTotal($1, path.union([id])) }
    subtree[id] = total
    return total
  }
  func sort(_ ids: [String]) -> [String] {
    ids.sorted {
      let left = subtreeTotal($0, [])
      let right = subtreeTotal($1, [])
      if left != right {
        return left > right
      }
      return $0 < $1
    }
  }
  func matches(_ id: String) -> Bool {
    guard !query.isEmpty else {
      return true
    }
    let process = identities[id]
    return process?.name.localizedCaseInsensitiveContains(query) == true
      || id.localizedCaseInsensitiveContains(query)
  }
  func visible(_ id: String, _ path: Set<String>) -> Bool {
    if matches(id) {
      return true
    }
    guard !path.contains(id) else {
      return false
    }
    return (children[id] ?? []).contains { visible($0, path.union([id])) }
  }
  var rows: [ProcessRow] = []
  func append(_ id: String, depth: Int, _ path: Set<String>) {
    guard let process = identities[id], !path.contains(id) else {
      return
    }
    let childIDs = sort((children[id] ?? []).filter { visible($0, []) })
    rows.append(
      ProcessRow(
        process: process,
        depth: depth,
        individualTotal: totals[id] ?? 0,
        subtreeTotal: subtreeTotal(id, []),
        isExpanded: expanded.contains(id),
        hasChildren: !childIDs.isEmpty,
        matchesQuery: matches(id)
      )
    )
    if expanded.contains(id) || !query.isEmpty {
      for child in childIDs {
        append(child, depth: depth + 1, path.union([id]))
      }
    }
  }
  for root in sort(roots.filter { visible($0, []) }) {
    append(root, depth: 0, [])
  }
  return rows
}

public func makeMonitoringStatus(_ observation: Observation?) -> MonitoringStatus {
  guard let observation else {
    return MonitoringStatus(headline: "Monitoring normal")
  }
  switch observation.mode {
  case .normal:
    return MonitoringStatus(headline: "Monitoring normal")
  case .reduced(let reason, let affectedMetrics):
    let affected = affectedMetrics.sorted().joined(separator: ", ")
    return MonitoringStatus(
      headline: "Reduced monitoring",
      detail: affected.isEmpty ? reason : "\(reason) · \(affected)"
    )
  case .highDetail(let remaining, let limit, let warning):
    let remainingSeconds = Int(remaining.rounded())
    let limitSeconds = Int(limit.rounded())
    let detail =
      warning
      ? "ending soon · \(remainingSeconds)s remaining of \(limitSeconds)s limit"
      : "\(remainingSeconds)s remaining of \(limitSeconds)s limit"
    return MonitoringStatus(headline: "High-detail investigation", detail: detail)
  }
}

public struct TimelinePoint: Sendable, Equatable {
  public let timestamp: Date
  public let valuesByMetric: [String: Double]
  public let hasUnavailableData: Bool
  public let markerKinds: [TimelineMarker.Kind]
  public let observationNotes: [String]
  public let tooltip: String

  public init(
    timestamp: Date,
    valuesByMetric: [String: Double],
    hasUnavailableData: Bool,
    markerKinds: [TimelineMarker.Kind],
    observationNotes: [String],
    tooltip: String
  ) {
    self.timestamp = timestamp
    self.valuesByMetric = valuesByMetric
    self.hasUnavailableData = hasUnavailableData
    self.markerKinds = markerKinds
    self.observationNotes = observationNotes
    self.tooltip = tooltip
  }
}

public func makeTimelinePoints(_ timeline: IncidentTimeline) -> [TimelinePoint] {
  let timestamps = Set(
    timeline.metricSamples.map(\.timestamp)
      + timeline.gaps.map(\.timestamp)
      + timeline.markers.map(\.timestamp)
      + timeline.observationTransitions.map(\.timestamp)
  ).sorted()
  return timestamps.map { timestamp in
    let values = Dictionary(
      uniqueKeysWithValues: timeline.metricSamples
        .filter { $0.timestamp == timestamp }
        .compactMap { sample in sample.value.map { (sample.metric, $0) } }
    )
    let unavailable = timeline.gaps.contains { $0.timestamp == timestamp }
    let markers = timeline.markers.filter { $0.timestamp == timestamp }.map(\.kind)
    let notes = timeline.observationTransitions
      .filter { $0.timestamp == timestamp }
      .map(\.reason)
    var entries = values.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }
    if unavailable {
      entries.append("data unavailable")
    }
    entries += markers.map { kind in
      switch kind {
      case .started: return "incident started"
      case .peak: return "incident peak"
      case .recovered: return "incident recovered"
      }
    }
    entries += notes
    return TimelinePoint(
      timestamp: timestamp,
      valuesByMetric: values,
      hasUnavailableData: unavailable,
      markerKinds: markers,
      observationNotes: notes,
      tooltip: entries.joined(separator: " · ")
    )
  }
}

public struct Explanation: Sendable, Equatable {
  public let facts: [String]
  public let correlations: [String]
  public let hypotheses: [String]
  public let uncertainty: [String]
  public let unavailable: [String]

  public init(
    facts: [String],
    correlations: [String],
    hypotheses: [String],
    uncertainty: [String],
    unavailable: [String]
  ) {
    self.facts = facts
    self.correlations = correlations
    self.hypotheses = hypotheses
    self.uncertainty = uncertainty
    self.unavailable = unavailable
  }
}

func iso(_ date: Date) -> String {
  ISO8601DateFormatter().string(from: date)
}

public func formatRate(_ bytesPerSecond: Double) -> String {
  guard bytesPerSecond >= 0 else {
    return "–"
  }
  if bytesPerSecond < 1024 {
    return "\(Int(bytesPerSecond)) B/s"
  }
  if bytesPerSecond < 1_048_576 {
    return String(format: "%.1f KB/s", bytesPerSecond / 1024)
  }
  return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
}

/// Y-domain for live sparklines: pads varying data, centers constant data
/// so flat readings render as a band instead of a line glued to an edge.
public func chartDomain(values: [Double]) -> ClosedRange<Double> {
  guard let lo = values.min(), let hi = values.max() else {
    return 0...1
  }
  if hi > lo {
    let padding = max((hi - lo) * 0.25, 0.02)
    return max(0, lo - padding)...min(1, hi + padding)
  }
  return max(0, lo - 0.1)...min(1, hi + 0.1)
}

public func makeExplanation(_ timeline: IncidentTimeline) -> Explanation {
  let incident = timeline.incident
  var facts: [String] = []
  if let recoveredAt = incident.recoveredAt {
    facts.append("Incident observed from \(iso(incident.startedAt)) to \(iso(recoveredAt)).")
  } else {
    facts.append("Incident observed from \(iso(incident.startedAt)); still ongoing.")
  }
  let metrics = Set(timeline.metricSamples.map(\.metric)).sorted()
  if metrics.isEmpty {
    facts.append("No readings recorded for this incident.")
  } else {
    for metric in metrics {
      let values = timeline.metricSamples.filter { $0.metric == metric }.compactMap(\.value)
      guard !values.isEmpty, let min = values.min(), let max = values.max() else {
        continue
      }
      facts.append("\(metric): \(values.count) readings, min \(min), max \(max).")
    }
  }
  if let top = timeline.relevantProcesses.first {
    let share = (top.contribution * 100).rounded() / 100
    facts.append("\(top.process.name) held the largest share (\(share)) during the incident.")
  }
  let correlations = timeline.relevantProcesses.map {
    "\($0.process.name) was active during the incident."
  }
  let hypotheses: [String]
  if let top = timeline.relevantProcesses.first {
    hypotheses = [
      "Possible cause (unproven): \(top.process.name)'s resource use is related to this incident."
    ]
  } else {
    hypotheses = ["No hypothesis can be formed from the available evidence."]
  }
  var uncertainty: [String] = []
  if !timeline.gaps.isEmpty {
    let count = timeline.gaps.count
    uncertainty.append(
      "Evidence is incomplete: \(count) sample\(count == 1 ? " is" : "s are") missing."
    )
  }
  if !timeline.observationTransitions.isEmpty {
    uncertainty.append("Observation quality changed during the incident.")
  }
  if incident.recoveredAt == nil {
    uncertainty.append("The incident has not recovered; its full extent is unknown.")
  }
  let unavailable = timeline.gaps.map { "sample missing at \(iso($0.timestamp))." }
  return Explanation(
    facts: facts,
    correlations: correlations,
    hypotheses: hypotheses,
    uncertainty: uncertainty,
    unavailable: unavailable
  )
}
