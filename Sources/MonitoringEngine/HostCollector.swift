import Darwin
import Foundation

/// Reads live memory and disk figures and shapes them into the sampling
/// seam's samples. System CPU deliberately lives elsewhere: Mach tick
/// counters freeze under tickless idle on Apple Silicon and read a
/// permanent ~100%, so CPU shares derive from per-process time deltas
/// (see ProcessCollector.systemCPUSample). Memory use is an
/// approximation: process-attributed pages over physical pages, clamped
/// to a fraction.
public struct HostCollector<C: Clock> {
  private let clock: C
  public private(set) var lastDuration: TimeInterval = 0

  public init(clock: C) {
    self.clock = clock
  }

  public mutating func collect(now: Date) -> [Sample] {
    let started = clock.now()
    defer { lastDuration = clock.now().timeIntervalSince(started) }
    return [memorySample(at: now), diskSample(at: now)]
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
