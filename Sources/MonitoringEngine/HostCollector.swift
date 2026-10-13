import Darwin
import Foundation

/// Reads live CPU and memory figures from Mach host statistics and shapes
/// them into the sampling seam's samples. CPU utilization needs two reads
/// to form a delta, so the first collection honestly reports unavailable.
/// Memory use is an approximation: process-attributed pages over physical
/// pages, clamped to a fraction.
public struct HostCollector<C: Clock> {
  private let clock: C
  private var previousTicks: CPUTicks?
  public private(set) var lastDuration: TimeInterval = 0

  public init(clock: C) {
    self.clock = clock
  }

  public mutating func collect(now: Date) -> [Sample] {
    let started = clock.now()
    defer { lastDuration = clock.now().timeIntervalSince(started) }
    return [cpuSample(at: now), memorySample(at: now), diskSample(at: now)]
  }

  private struct CPUTicks: Equatable {
    let user: UInt64
    let system: UInt64
    let nice: UInt64
    let idle: UInt64
  }

  private mutating func cpuSample(at now: Date) -> Sample {
    guard let ticks = Self.cpuTicks() else {
      return Sample(timestamp: now, availability: .unavailable, metric: "cpu")
    }
    defer { previousTicks = ticks }
    guard let previous = previousTicks else {
      return Sample(timestamp: now, availability: .unavailable, metric: "cpu")
    }
    let busy = (ticks.user &- previous.user) &+ (ticks.system &- previous.system)
      &+ (ticks.nice &- previous.nice)
    let total = busy &+ (ticks.idle &- previous.idle)
    guard total > 0 else {
      return Sample(timestamp: now, availability: .unavailable, metric: "cpu")
    }
    return Sample(
      timestamp: now,
      availability: .available,
      value: Double(busy) / Double(total),
      metric: "cpu"
    )
  }

  private static func cpuTicks() -> CPUTicks? {
    var info = host_cpu_load_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else {
      return nil
    }
    return CPUTicks(
      user: UInt64(info.cpu_ticks.0),
      system: UInt64(info.cpu_ticks.1),
      nice: UInt64(info.cpu_ticks.2),
      idle: UInt64(info.cpu_ticks.3)
    )
  }

  private func diskSample(at now: Date) -> Sample {
    guard
      let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
      let total = attributes[.systemSize] as? NSNumber,
      let free = attributes[.systemFreeSize] as? NSNumber,
      total.doubleValue > 0
    else {
      return Sample(timestamp: now, availability: .unavailable, metric: "disk")
    }
    let fraction = min(max(1 - free.doubleValue / total.doubleValue, 0), 1)
    return Sample(timestamp: now, availability: .available, value: fraction, metric: "disk")
  }

  private func memorySample(at now: Date) -> Sample {
    var info = vm_statistics64_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
    )
    let host = mach_host_self()
    defer { mach_port_deallocate(mach_task_self_, host) }
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(host, HOST_VM_INFO64, $0, &count)
      }
    }
    var pageSize: vm_size_t = 0
    host_page_size(host, &pageSize)
    guard result == KERN_SUCCESS, pageSize > 0 else {
      return Sample(timestamp: now, availability: .unavailable, metric: "memory")
    }
    let totalPages = UInt64(ProcessInfo.processInfo.physicalMemory) / UInt64(pageSize)
    let used =
      UInt64(info.active_count) + UInt64(info.inactive_count) + UInt64(info.wire_count)
      + UInt64(info.compressor_page_count)
    guard totalPages > 0 else {
      return Sample(timestamp: now, availability: .unavailable, metric: "memory")
    }
    let fraction = min(max(Double(used) / Double(totalPages), 0), 1)
    return Sample(timestamp: now, availability: .available, value: fraction, metric: "memory")
  }
}
