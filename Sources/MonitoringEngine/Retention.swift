import Foundation

public struct RetentionPolicy: Sendable, Equatable {
  public let detailRetention: TimeInterval
  public let quota: Int
  public let thresholdsByMetric: [String: Double]

  public init(detailRetention: TimeInterval, quota: Int, thresholdsByMetric: [String: Double]) {
    self.detailRetention = detailRetention
    self.quota = quota
    self.thresholdsByMetric = thresholdsByMetric
  }
}

public struct SampleSummary: Sendable, Equatable {
  public let metric: String
  public let start: Date
  public let end: Date
  public let count: Int
  public let min: Double
  public let max: Double
  public let average: Double
  public let variation: Double
  public let thresholdExceededDuration: TimeInterval
  public let incidentCount: Int

  public init(
    metric: String,
    start: Date,
    end: Date,
    count: Int,
    min: Double,
    max: Double,
    average: Double,
    variation: Double,
    thresholdExceededDuration: TimeInterval,
    incidentCount: Int
  ) {
    self.metric = metric
    self.start = start
    self.end = end
    self.count = count
    self.min = min
    self.max = max
    self.average = average
    self.variation = variation
    self.thresholdExceededDuration = thresholdExceededDuration
    self.incidentCount = incidentCount
  }
}

public struct HistorySnapshot: Sendable, Equatable {
  public let details: [Sample]
  public let summaries: [SampleSummary]
  public let incidents: [Incident]
  public let pinned: [Incident]
  public let storageUnits: Int
  public let quota: Int

  public init(
    details: [Sample],
    summaries: [SampleSummary],
    incidents: [Incident],
    pinned: [Incident],
    storageUnits: Int,
    quota: Int
  ) {
    self.details = details
    self.summaries = summaries
    self.incidents = incidents
    self.pinned = pinned
    self.storageUnits = storageUnits
    self.quota = quota
  }
}

struct HistoryStore {
  var details: [Sample] = []
  var summaries: [SampleSummary] = []
  var incidents: [Incident] = []
  var pinned: [Incident] = []
  let policy: RetentionPolicy

  mutating func record(samples newSamples: [Sample], incidents newIncidents: [Incident], now: Date) {
    details += newSamples
    for incident in newIncidents where !incidents.contains(incident) {
      incidents.append(incident)
    }
    compactOlderThan(now.addingTimeInterval(-policy.detailRetention))
    enforceQuota()
  }

  mutating func pin(_ incident: Incident) {
    if !pinned.contains(incident) {
      pinned.append(incident)
    }
  }

  func snapshot() -> HistorySnapshot {
    HistorySnapshot(
      details: details,
      summaries: summaries,
      incidents: incidents,
      pinned: pinned,
      storageUnits: details.count,
      quota: policy.quota
    )
  }

  private mutating func enforceQuota() {
    var excess = details.count - policy.quota
    while excess > 0 {
      let spans = protectedSpans()
      let ordered = details.sorted { $0.timestamp < $1.timestamp }
      let victimIndices = Set(
        ordered.indices.filter { !inside(ordered[$0].timestamp, spans) }.prefix(excess)
      )
      guard !victimIndices.isEmpty else {
        return
      }
      let victims = victimIndices.sorted().map { ordered[$0] }
      details =
        ordered
        .enumerated()
        .filter { !victimIndices.contains($0.offset) }
        .map(\.element)
      summarize(victims, spans: spans)
      excess = details.count - policy.quota
    }
  }

  private mutating func compactOlderThan(_ cutoff: Date) {
    let spans = protectedSpans()
    var kept: [Sample] = []
    kept.reserveCapacity(details.count)
    var victims: [Sample] = []
    for sample in details {
      if sample.timestamp < cutoff && !inside(sample.timestamp, spans) {
        victims.append(sample)
      } else {
        kept.append(sample)
      }
    }
    guard !victims.isEmpty else {
      return
    }
    details = kept
    summarize(victims, spans: spans)
  }

  private func protectedSpans() -> [(Date, Date)] {
    let protected = incidents.filter {
      if case .rule = $0.source {
        return true
      }
      return false
    } + pinned
    return protected.map { ($0.startedAt, $0.recoveredAt ?? .distantFuture) }
  }

  private func inside(_ timestamp: Date, _ spans: [(Date, Date)]) -> Bool {
    spans.contains { timestamp >= $0.0 && timestamp < $0.1 }
  }

  private mutating func summarize(_ samples: [Sample], spans: [(Date, Date)]) {
    for metric in Set(samples.map(\.metric)).sorted() {
      let group = samples.filter { $0.metric == metric }.sorted { $0.timestamp < $1.timestamp }
      var runs: [[Sample]] = []
      for sample in group {
        if let last = runs.last?.last,
          spans.contains(where: { $0.0 > last.timestamp && $0.0 <= sample.timestamp })
        {
          runs.append([sample])
        } else if runs.isEmpty {
          runs.append([sample])
        } else {
          runs[runs.count - 1].append(sample)
        }
      }
      for run in runs {
        summarizeRun(run, metric: metric)
      }
    }
  }

  private mutating func summarizeRun(_ group: [Sample], metric: String) {
    guard let start = group.first?.timestamp, let end = group.last?.timestamp else {
      return
    }
    let values = group.compactMap(\.value)
    let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    let variance =
      values.isEmpty
      ? 0 : values.map { ($0 - average) * ($0 - average) }.reduce(0, +) / Double(values.count)
    var exceeded: TimeInterval = 0
    if let threshold = policy.thresholdsByMetric[metric] {
      for index in group.indices where (group[index].value ?? -.infinity) >= threshold {
        if index + 1 < group.count {
          exceeded += group[index + 1].timestamp.timeIntervalSince(group[index].timestamp)
        }
      }
    }
    let overlapping = incidents.filter { incident in
      let incidentEnd = incident.recoveredAt ?? .distantFuture
      return incident.startedAt <= end && incidentEnd >= start
    }
    summaries.append(
      SampleSummary(
        metric: metric,
        start: start,
        end: end,
        count: group.count,
        min: values.min() ?? 0,
        max: values.max() ?? 0,
        average: average,
        variation: variance.squareRoot(),
        thresholdExceededDuration: exceeded,
        incidentCount: overlapping.count
      )
    )
  }
}
