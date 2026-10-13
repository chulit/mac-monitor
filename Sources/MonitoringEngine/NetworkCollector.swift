import Darwin
import Foundation

/// Measures interface throughput from kernel byte counters over physical
/// interfaces (`en*`), shaped into the sampling seam's samples. Like CPU
/// shares, a rate needs two reads: the first collection honestly reports
/// unavailable. Zero traffic is a genuine zero reading, not a gap.
public struct NetworkCollector {
  private var previousBytes: (in: UInt64, out: UInt64)?
  private var previousNow: Date?

  public init() {}

  public mutating func collect(now: Date) -> [Sample] {
    defer {
      if let counters = Self.counters() {
        previousBytes = counters
        previousNow = now
      }
    }
    guard let counters = Self.counters(),
      let previous = previousBytes,
      let previousNow,
      now > previousNow,
      let rate = Self.rate(
        inDelta: counters.in &- previous.in,
        outDelta: counters.out &- previous.out,
        elapsed: now.timeIntervalSince(previousNow)
      )
    else {
      return [Sample(timestamp: now, availability: .unavailable, metric: "network")]
    }
    return [
      Sample(timestamp: now, availability: .available, value: rate, metric: "network")
    ]
  }

  static func rate(inDelta: UInt64, outDelta: UInt64, elapsed: TimeInterval) -> Double? {
    guard elapsed > 0 else {
      return nil
    }
    return Double(inDelta &+ outDelta) / elapsed
  }

  private static func counters() -> (in: UInt64, out: UInt64)? {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0, let first = head else {
      return nil
    }
    defer { freeifaddrs(head) }
    var totalIn: UInt64 = 0
    var totalOut: UInt64 = 0
    var found = false
    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let current = cursor {
      let interface = current.pointee
      cursor = interface.ifa_next
      guard let name = interface.ifa_name.map({ String(cString: $0) }),
        name.hasPrefix("en"),
        let data = interface.ifa_data
      else {
        continue
      }
      let stats = data.assumingMemoryBound(to: if_data.self).pointee
      totalIn &+= UInt64(stats.ifi_ibytes)
      totalOut &+= UInt64(stats.ifi_obytes)
      found = true
    }
    return found ? (totalIn, totalOut) : nil
  }
}
