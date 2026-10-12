import Foundation

public struct Process: Sendable, Equatable, Hashable {
  public let id: String
  public let parent: String?
  public let name: String

  public init(id: String, parent: String?, name: String) {
    self.id = id
    self.parent = parent
    self.name = name
  }
}

public struct ProcessSample: Sendable, Equatable {
  public let timestamp: Date
  public let process: Process
  public let metric: String
  public let value: Double

  public init(timestamp: Date, process: Process, metric: String, value: Double) {
    self.timestamp = timestamp
    self.process = process
    self.metric = metric
    self.value = value
  }
}

public struct ProcessRelevance: Sendable, Equatable {
  public let process: Process
  public let contribution: Double
  public let reasons: [String]

  public init(process: Process, contribution: Double, reasons: [String]) {
    self.process = process
    self.contribution = contribution
    self.reasons = reasons
  }
}

public func rankRelevance(
  processes: [ProcessSample],
  from start: Date,
  through end: Date
) -> [ProcessRelevance] {
  var totals: [String: Double] = [:]
  var identities: [String: Process] = [:]
  for sample in processes {
    identities[sample.process.id] = sample.process
    guard sample.timestamp >= start && sample.timestamp <= end else {
      continue
    }
    totals[sample.process.id, default: 0] += sample.value
  }
  let grand = totals.values.reduce(0, +)
  guard grand > 0 else {
    return []
  }
  let ranked = totals.compactMap { (id, total) -> (Process, Double)? in
    let share = total / grand
    guard share >= 0.05, let process = identities[id] else {
      return nil
    }
    return (process, share)
  }.sorted {
    if $0.1 != $1.1 {
      return $0.1 > $1.1
    }
    return $0.0.id < $1.0.id
  }
  var relevance = ranked.enumerated().map { index, entry in
    ProcessRelevance(
      process: entry.0,
      contribution: entry.1,
      reasons: [
        index == 0
          ? "largest resource share during incident"
          : "elevated resource share during incident"
      ]
    )
  }
  let listed = Set(ranked.map { $0.0.id })
  var seen = listed
  for entry in ranked {
    var child = entry.0
    while let parentID = child.parent, !seen.contains(parentID) {
      seen.insert(parentID)
      guard let parent = identities[parentID] else {
        break
      }
      let share = (totals[parentID] ?? 0) / grand
      relevance.append(
        ProcessRelevance(
          process: parent,
          contribution: share,
          reasons: ["ancestor of elevated process \(child.name)"]
        )
      )
      child = parent
    }
  }
  return relevance
}
