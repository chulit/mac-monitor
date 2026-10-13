import Darwin
import Foundation

/// Enumerates live processes through libproc and shapes per-process CPU
/// shares into the sampling seam's process samples. Identity tokens bind
/// pid to process start time, so a reused pid never matches a stale token.
/// CPU shares need two collections to form a delta; newly seen processes
/// are omitted until their second sighting rather than zero-filled.
public struct ProcessIdentity: Sendable, Equatable {
  public let pid: Int32
  public let token: String
  public let name: String

  public init(pid: Int32, token: String, name: String) {
    self.pid = pid
    self.token = token
    self.name = name
  }
}

/// Sums one process's resource values across the given samples for budget
/// reporting. Absent processes yield nil, never zero: a missing reading
/// must not masquerade as idle.
public func totalShare(processes: [ProcessSample], pid: Int32) -> Double? {
  let matching = processes.filter { $0.process.id == String(pid) }
  guard !matching.isEmpty else {
    return nil
  }
  return min(matching.reduce(0) { $0 + $1.value }, 1)
}

public struct ProcessCollector {
  private var previousUsage: [Int32: (user: UInt64, system: UInt64)] = [:]
  private var identities: [Int32: ProcessIdentity] = [:]
  private var previousParents: [Int32: Int32] = [:]
  private var previousNow: Date?

  public init() {}

  public mutating func collect(now: Date) -> [ProcessSample] {
    let current = Self.enumerate()
    defer {
      previousUsage = current.usages
      identities = current.identities
      previousParents = current.parents
      previousNow = now
    }
    guard let previousNow, now > previousNow else {
      return []
    }
    let elapsed = now.timeIntervalSince(previousNow)
    let processors = max(ProcessInfo.processInfo.processorCount, 1)
    var samples: [ProcessSample] = []
    for (pid, usage) in current.usages {
      guard let previous = previousUsage[pid],
        let identity = current.identities[pid],
        let share = Self.cpuShare(
          userDeltaNanos: usage.user &- previous.user,
          systemDeltaNanos: usage.system &- previous.system,
          elapsedNanos: elapsed,
          processorCount: processors
        )
      else {
        continue
      }
      let parent = current.parents[pid].flatMap { $0 > 0 ? String($0) : nil }
      samples.append(
        ProcessSample(
          timestamp: now,
          process: Process(id: String(pid), parent: parent, name: identity.name),
          metric: "cpu",
          value: share
        )
      )
    }
    return samples.sorted { $0.process.id < $1.process.id }
  }

  public func identity(for process: Process) -> ProcessIdentity? {
    guard let pid = Int32(process.id) else {
      return nil
    }
    return identities[pid]
  }

  static func cpuShare(
    userDeltaNanos: UInt64,
    systemDeltaNanos: UInt64,
    elapsedNanos: TimeInterval,
    processorCount: Int
  ) -> Double? {
    guard elapsedNanos > 0, processorCount > 0 else {
      return nil
    }
    let total = userDeltaNanos &+ systemDeltaNanos
    let capacity = UInt64(elapsedNanos * 1_000_000_000) * UInt64(processorCount)
    guard capacity > 0 else {
      return nil
    }
    return min(max(Double(total) / Double(capacity), 0), 1)
  }

  private struct Enumeration {
    var usages: [Int32: (user: UInt64, system: UInt64)] = [:]
    var identities: [Int32: ProcessIdentity] = [:]
    var parents: [Int32: Int32] = [:]
  }

  private static func enumerate() -> Enumeration {
    var result = Enumeration()
    for pid in allPIDs() {
      var info = proc_bsdinfo()
      let infoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
      guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, infoSize) == infoSize else {
        continue
      }
      var usage = rusage_info_v2()
      let usageRead: Int32 = withUnsafeMutablePointer(to: &usage) {
        $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
          proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
        }
      }
      guard usageRead == 0 else {
        continue
      }
      let name = withUnsafePointer(to: info.pbi_comm) {
        $0.withMemoryRebound(to: CChar.self, capacity: 16) { String(cString: $0) }
      }
      let token = "\(info.pbi_pid)-\(info.pbi_start_tvsec)-\(info.pbi_start_tvusec)"
      let pidValue = Int32(truncatingIfNeeded: info.pbi_pid)
      result.usages[pidValue] = (usage.ri_user_time, usage.ri_system_time)
      result.identities[pidValue] = ProcessIdentity(
        pid: pidValue,
        token: token,
        name: name
      )
      result.parents[pidValue] = Int32(truncatingIfNeeded: info.pbi_ppid)
    }
    return result
  }

  private static func allPIDs() -> [pid_t] {
    var capacity = 4096
    for _ in 0..<3 {
      var buffer = [pid_t](repeating: 0, count: capacity)
      let bytes = buffer.withUnsafeMutableBufferPointer {
        proc_listallpids($0.baseAddress, Int32($0.count * MemoryLayout<pid_t>.stride))
      }
      guard bytes > 0 else {
        return []
      }
      let count = Int(bytes) / MemoryLayout<pid_t>.stride
      if count < capacity {
        return Array(buffer.prefix(count)).filter { $0 > 0 }
      }
      capacity = count + 256
    }
    return []
  }
}
