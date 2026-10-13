import Foundation

/// Sort key for the processes table. Memory is deliberately absent: the
/// engine collects no per-process memory figures, and offering the sort
/// would imply data that does not exist.
public enum ProcessSort: String, Sendable, Equatable, CaseIterable {
  case cpu
  case name
  case pid
}

public struct ProcessTableEntry: Sendable, Equatable {
  public let process: Process
  /// Latest individual CPU share (0...1), clamped. Never a subtree
  /// aggregate: individual and subtree figures stay strictly separated.
  public let cpuShare: Double
  public let depth: Int
  public let isExpanded: Bool
  public let hasChildren: Bool
  public let parentName: String?

  public init(
    process: Process,
    cpuShare: Double,
    depth: Int,
    isExpanded: Bool,
    hasChildren: Bool,
    parentName: String?
  ) {
    self.process = process
    self.cpuShare = cpuShare
    self.depth = depth
    self.isExpanded = isExpanded
    self.hasChildren = hasChildren
    self.parentName = parentName
  }
}

/// Builds the process table rows for the Processes screen: flat or
/// hierarchical, filtered by query, sorted by the chosen key. A non-empty
/// query always flattens the tree so matches are never hidden inside a
/// collapsed parent.
public func processTableEntries(
  samples: [ProcessSample],
  query: String = "",
  sort: ProcessSort = .cpu,
  showTree: Bool = false,
  expanded: Set<String> = []
) -> [ProcessTableEntry] {
  var latest: [String: ProcessSample] = [:]
  for sample in samples where sample.metric == "cpu" {
    if let existing = latest[sample.process.id], existing.timestamp >= sample.timestamp {
      continue
    }
    latest[sample.process.id] = sample
  }
  let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
  var children: [String: [String]] = [:]
  for (id, sample) in latest {
    if let parent = sample.process.parent, latest[parent] != nil {
      children[parent, default: []].append(id)
    }
  }

  func sortIds(_ ids: [String]) -> [String] {
    ids.sorted { a, b in
      let left = latest[a]!
      let right = latest[b]!
      switch sort {
      case .cpu:
        if left.value != right.value {
          return left.value > right.value
        }
        return left.process.name.localizedCaseInsensitiveCompare(right.process.name)
          == .orderedAscending
      case .name:
        return left.process.name.localizedCaseInsensitiveCompare(right.process.name)
          == .orderedAscending
      case .pid:
        return (Int(a) ?? 0) < (Int(b) ?? 0)
      }
    }
  }

  func entry(for id: String, depth: Int, isExpanded: Bool, hasChildren: Bool) -> ProcessTableEntry {
    let sample = latest[id]!
    return ProcessTableEntry(
      process: sample.process,
      cpuShare: min(max(sample.value, 0), 1),
      depth: depth,
      isExpanded: isExpanded,
      hasChildren: hasChildren,
      parentName: sample.process.parent.flatMap { latest[$0]?.process.name }
    )
  }

  // A search always flattens: matches must not hide inside collapsed parents.
  if !showTree || !trimmed.isEmpty {
    let ids = latest.keys.filter { id in
      trimmed.isEmpty || latest[id]!.process.name.localizedCaseInsensitiveContains(trimmed)
    }
    return sortIds(ids).map { entry(for: $0, depth: 0, isExpanded: false, hasChildren: false) }
  }

  var entries: [ProcessTableEntry] = []
  func append(id: String, depth: Int, path: Set<String>) {
    guard !path.contains(id), let _ = latest[id] else {
      return
    }
    let kids = sortIds(children[id] ?? [])
    entries.append(entry(for: id, depth: depth, isExpanded: expanded.contains(id), hasChildren: !kids.isEmpty))
    if expanded.contains(id) {
      for kid in kids {
        append(id: kid, depth: depth + 1, path: path.union([id]))
      }
    }
  }
  let roots = latest.keys.filter { id in
    guard let parent = latest[id]?.process.parent else {
      return true
    }
    return latest[parent] == nil
  }
  for root in sortIds(roots) {
    append(id: root, depth: 0, path: [])
  }
  return entries
}
