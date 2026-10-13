import Foundation

/// Date range for the History screen.
public enum HistoryRange: String, Sendable, Equatable, CaseIterable {
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

/// Severity derived from peak intensity during the incident: the engine
/// stores no severity label, so this is defined explicitly — peak sample
/// value across fraction metrics in the incident window.
public enum IncidentSeverity: String, Sendable, Equatable, CaseIterable {
  case high = "High"
  case medium = "Medium"
  case low = "Low"

  public static func fromPeak(_ peak: Double?) -> IncidentSeverity? {
    guard let peak else {
      return nil
    }
    if peak >= 0.9 {
      return .high
    }
    if peak >= 0.7 {
      return .medium
    }
    return .low
  }
}

public enum SeverityFilter: String, Sendable, Equatable, CaseIterable {
  case all = "All"
  case high = "High"
  case medium = "Medium"
  case low = "Low"
}

public enum HistorySort: String, Sendable, Equatable, CaseIterable {
  case newest = "Newest First"
  case oldest = "Oldest First"
}

public struct ActivityPoint: Sendable, Equatable {
  public let date: Date
  public let value: Double

  public init(date: Date, value: Double) {
    self.date = date
    self.value = value
  }
}

/// Bucketed average series for one metric over the range, merging recent
/// detail samples with compact summary averages for older spans. The bucket
/// count is capped so multi-day ranges stay chartable.
public func activitySeries(
  details: [Sample],
  summaries: [SampleSummary],
  metric: String,
  range: HistoryRange,
  now: Date,
  maxPoints: Int = 300
) -> [ActivityPoint] {
  let cutoff = now.addingTimeInterval(-range.seconds)
  var points: [ActivityPoint] = []
  points.reserveCapacity(details.count)
  for sample in details where sample.metric == metric && sample.timestamp >= cutoff {
    if let value = sample.value {
      points.append(ActivityPoint(date: sample.timestamp, value: value))
    }
  }
  for summary in summaries where summary.metric == metric && summary.end >= cutoff {
    let mid = summary.start.addingTimeInterval(summary.end.timeIntervalSince(summary.start) / 2)
    points.append(ActivityPoint(date: mid, value: summary.average))
  }
  points.sort { $0.date < $1.date }
  guard points.count > maxPoints, maxPoints > 0 else {
    return points
  }
  let start = points.first!.date
  let end = points.last!.date
  let span = max(end.timeIntervalSince(start), 1e-9)
  var buckets = Array(repeating: (sum: 0.0, count: 0), count: maxPoints)
  for point in points {
    let index = min(Int(Double(maxPoints) * point.date.timeIntervalSince(start) / span), maxPoints - 1)
    buckets[index].sum += point.value
    buckets[index].count += 1
  }
  var result: [ActivityPoint] = []
  result.reserveCapacity(maxPoints)
  for index in 0..<maxPoints where buckets[index].count > 0 {
    let date = start.addingTimeInterval(span * (Double(index) + 0.5) / Double(maxPoints))
    result.append(ActivityPoint(
      date: date,
      value: buckets[index].sum / Double(buckets[index].count)
    ))
  }
  return result
}

public struct HistoricalIncident: Sendable, Equatable {
  public let incident: Incident
  /// Inferred from the highest peak across fraction metrics in the window;
  /// nil when no samples were recorded.
  public let metric: String?
  public let peak: Double?
  public let severity: IncidentSeverity?

  public init(incident: Incident, metric: String?, peak: Double?, severity: IncidentSeverity?) {
    self.incident = incident
    self.metric = metric
    self.peak = peak
    self.severity = severity
  }

  public var title: String {
    incidentTitle(incident: incident, metric: metric)
  }

  public var category: IncidentCategory {
    incidentCategory(metric: metric)
  }
}

/// Enriches recorded incidents with inferred metric, peak, and severity from
/// the detail samples inside each incident window. Dedupes by start time:
/// an incident recorded while active and again after recovery keeps the
/// recovered version.
public func historicalIncidents(
  incidents: [Incident],
  details: [Sample],
  now: Date
) -> [HistoricalIncident] {
  var deduped: [TimeInterval: Incident] = [:]
  for incident in incidents {
    let key = incident.startedAt.timeIntervalSince1970.rounded()
    if let existing = deduped[key] {
      if existing.recoveredAt == nil, incident.recoveredAt != nil {
        deduped[key] = incident
      }
    } else {
      deduped[key] = incident
    }
  }
  let fractionMetrics: Set<String> = ["cpu", "memory", "disk"]
  return deduped.values
    .sorted { $0.startedAt > $1.startedAt }
    .map { incident in
      let end = incident.recoveredAt ?? now
      var bestMetric: String?
      var bestPeak: Double?
      for metric in fractionMetrics {
        let peak = details
          .filter {
            $0.metric == metric && $0.timestamp >= incident.startedAt && $0.timestamp <= end
          }
          .compactMap(\.value)
          .max()
        if let peak, peak > (bestPeak ?? -1) {
          bestPeak = peak
          bestMetric = metric
        }
      }
      return HistoricalIncident(
        incident: incident,
        metric: bestMetric,
        peak: bestPeak,
        severity: IncidentSeverity.fromPeak(bestPeak)
      )
    }
}

public func filterHistoricalIncidents(
  _ items: [HistoricalIncident],
  severity: SeverityFilter,
  query: String,
  sort: HistorySort
) -> [HistoricalIncident] {
  let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
  let filtered = items.filter { item in
    let severityMatches: Bool = {
      switch severity {
      case .all: return true
      case .high: return item.severity == .high
      case .medium: return item.severity == .medium
      case .low: return item.severity == .low
      }
    }()
    guard severityMatches else {
      return false
    }
    guard !trimmed.isEmpty else {
      return true
    }
    return item.title.localizedCaseInsensitiveContains(trimmed)
      || (item.metric?.localizedCaseInsensitiveContains(trimmed) ?? false)
  }
  switch sort {
  case .newest:
    return filtered.sorted { $0.incident.startedAt > $1.incident.startedAt }
  case .oldest:
    return filtered.sorted { $0.incident.startedAt < $1.incident.startedAt }
  }
}

/// Synthetic timeline for a historical incident, built from recorded detail
/// samples around the incident window. Lets the detail screen reuse the
/// incident chart and the package export instead of duplicating them.
public func historicalTimeline(
  incident: Incident,
  details: [Sample],
  now: Date
) -> IncidentTimeline {
  let end = incident.recoveredAt ?? now
  let duration = max(end.timeIntervalSince(incident.startedAt), 1)
  let pad = duration * 0.5
  let windowStart = incident.startedAt.addingTimeInterval(-pad)
  let windowEnd = end.addingTimeInterval(pad)
  let samples = details
    .filter { $0.timestamp >= windowStart && $0.timestamp <= windowEnd }
    .sorted { $0.timestamp < $1.timestamp }
  var markers = [
    TimelineMarker(timestamp: incident.startedAt, kind: .started),
    TimelineMarker(timestamp: incident.peakAt, kind: .peak),
  ]
  if let recoveredAt = incident.recoveredAt {
    markers.append(TimelineMarker(timestamp: recoveredAt, kind: .recovered))
  }
  return IncidentTimeline(
    incident: incident,
    metricSamples: samples,
    gaps: [],
    markers: markers,
    ruleVersion: nil,
    baselineVersion: nil,
    relevantProcesses: []
  )
}

public struct SystemContext: Sendable, Equatable {
  public let memoryFraction: Double?
  public let diskFraction: Double?
  /// Bytes per second.
  public let networkRate: Double?

  public init(memoryFraction: Double?, diskFraction: Double?, networkRate: Double?) {
    self.memoryFraction = memoryFraction
    self.diskFraction = diskFraction
    self.networkRate = networkRate
  }
}

/// Auxiliary subsystem readings nearest the incident's peak, within five
/// minutes. Anything missing stays nil.
public func systemContext(
  incident: Incident,
  details: [Sample]
) -> SystemContext {
  func nearest(metric: String) -> Double? {
    let candidates = details.filter { $0.metric == metric }
    guard
      let best = candidates.min(by: {
        abs($0.timestamp.timeIntervalSince(incident.peakAt))
          < abs($1.timestamp.timeIntervalSince(incident.peakAt))
      }),
      abs(best.timestamp.timeIntervalSince(incident.peakAt)) <= 300
    else {
      return nil
    }
    return best.value
  }
  return SystemContext(
    memoryFraction: nearest(metric: "memory"),
    diskFraction: nearest(metric: "disk"),
    networkRate: nearest(metric: "network")
  )
}

/// Honest one-paragraph narrative composed from recorded facts only.
public func incidentNarrative(
  item: HistoricalIncident,
  now: Date
) -> String {
  let incident = item.incident
  let metricLabel: String = {
    switch item.metric {
    case "cpu": return "CPU usage"
    case "memory": return "Memory usage"
    case "disk": return "Disk activity"
    case "network": return "Network activity"
    default: return "System activity"
    }
  }()
  let peakText: String = {
    guard let peak = item.peak else {
      return "reached unusual levels"
    }
    if item.metric == "memory" {
      return "peaked at \(String(format: "%.0f%%", peak * 100)) of capacity"
    }
    if let metric = item.metric, ["cpu", "disk"].contains(metric) {
      return "peaked at \(String(format: "%.0f%%", peak * 100))"
    }
    return "peaked at \(String(format: "%.1f", peak))"
  }()
  let end = incident.recoveredAt ?? now
  let duration = formatDuration(end.timeIntervalSince(incident.startedAt))
  if incident.recoveredAt == nil {
    return
      "\(metricLabel) \(peakText) and is still ongoing (running for \(duration)). No process attribution was recorded for this historical incident."
  }
  return
    "\(metricLabel) \(peakText). The incident lasted \(duration) and has recovered. No process attribution was recorded for this historical incident."
}
