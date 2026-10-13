import Foundation

/// Anomaly category driving the badge icon and color on the overview cards.
public enum IncidentCategory: String, Sendable, CaseIterable {
  case cpu
  case memory
  case disk
  case network
  case unknown
}

public func incidentCategory(metric: String?) -> IncidentCategory {
  switch metric?.lowercased() {
  case "cpu": return .cpu
  case "memory": return .memory
  case "disk": return .disk
  case "network": return .network
  default: return .unknown
  }
}

/// "High CPU Usage" for rule incidents, "Unusual behavior" for baseline ones.
/// Shared by the popover and the overview cards so the wording never drifts.
public func incidentTitle(incident: Incident, metric: String?) -> String {
  switch incident.source {
  case .rule:
    return "High \((metric ?? "metric").uppercased()) Usage"
  case .baseline:
    return "Unusual behavior"
  }
}

/// "just now", "5m ago", "2h ago", "3d ago".
public func relativeTimeString(from date: Date, to now: Date) -> String {
  let seconds = now.timeIntervalSince(date)
  if seconds < 60 {
    return "just now"
  }
  if seconds < 3_600 {
    return "\(Int(seconds / 60))m ago"
  }
  if seconds < 86_400 {
    return "\(Int(seconds / 3_600))h ago"
  }
  return "\(Int(seconds / 86_400))d ago"
}

public struct TopProcess: Sendable, Equatable {
  public let process: Process
  public let share: Double

  public init(process: Process, share: Double) {
    self.process = process
    self.share = share
  }
}

/// Latest sample per process for the metric, sorted by share descending.
/// Shares are clamped to 0...1 so a rogue reading never overflows the bar.
public func topProcesses(samples: [ProcessSample], metric: String, limit: Int) -> [TopProcess] {
  var latest: [String: ProcessSample] = [:]
  for sample in samples where sample.metric == metric {
    if let existing = latest[sample.process.id], existing.timestamp >= sample.timestamp {
      continue
    }
    latest[sample.process.id] = sample
  }
  return latest.values
    .sorted { $0.value > $1.value }
    .prefix(max(limit, 0))
    .map { TopProcess(process: $0.process, share: min(max($0.value, 0), 1)) }
}
