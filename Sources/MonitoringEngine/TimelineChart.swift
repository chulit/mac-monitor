import Foundation

/// Which metric the usage timeline chart shows. Fractional metrics render a
/// fixed 0–100% axis; network renders byte rates with a data-driven axis.
public enum TimelineMetric: String, CaseIterable, Sendable {
  case cpu
  case memory
  case disk
  case network

  public var title: String {
    switch self {
    case .cpu: return "CPU Usage"
    case .memory: return "Memory Usage"
    case .disk: return "Disk Usage"
    case .network: return "Network Activity"
    }
  }

  public var pillTitle: String {
    switch self {
    case .cpu: return "CPU"
    case .memory: return "Memory"
    case .disk: return "Disk"
    case .network: return "Network"
    }
  }

  public var isFractional: Bool {
    self != .network
  }
}

public struct AxisTick: Sendable, Equatable {
  public var value: Double
  public var label: String

  public init(value: Double, label: String) {
    self.value = value
    self.label = label
  }
}

/// Rounds up to a 1/2/2.5/5/10 × power-of-ten ceiling for axis tops.
func niceCeiling(_ value: Double) -> Double {
  guard value > 0, value.isFinite else {
    return 1
  }
  let magnitude = pow(10, floor(log10(value)))
  let normalized = value / magnitude
  let nice: Double
  if normalized <= 1 {
    nice = 1
  } else if normalized <= 2 {
    nice = 2
  } else if normalized <= 2.5 {
    nice = 2.5
  } else if normalized <= 5 {
    nice = 5
  } else {
    nice = 10
  }
  return nice * magnitude
}

/// Five evenly spaced Y ticks. Fractional metrics get the fixed 100%…0%
/// scale; rates get a nice-ceiling max with formatted rate labels.
public func yAxisTicks(values: [Double], fractional: Bool) -> [AxisTick] {
  if fractional {
    return [1.0, 0.75, 0.5, 0.25, 0.0].map { fraction in
      AxisTick(value: fraction, label: "\(Int((fraction * 100).rounded()))%")
    }
  }
  let niceMax = niceCeiling(values.filter(\.isFinite).max() ?? 0)
  return [1.0, 0.75, 0.5, 0.25, 0.0].map { fraction in
    AxisTick(value: niceMax * fraction, label: formatRate(niceMax * fraction))
  }
}

/// Evenly spaced time markers across the window. Empty for nonsense input.
public func timeAxisMarkers(from start: Date, to end: Date, count: Int) -> [Date] {
  guard count >= 2, end > start else {
    return []
  }
  let span = end.timeIntervalSince(start)
  return (0..<count).map { index in
    start.addingTimeInterval(span * Double(index) / Double(count - 1))
  }
}

/// Samples inside the selected range ending at `now`. Old samples outside the
/// window are dropped; nothing is interpolated or fabricated.
public func samples(
  in range: OverviewTimeRange,
  endingAt now: Date,
  from history: [(date: Date, value: Double)]
) -> [(date: Date, value: Double)] {
  let cutoff = now.addingTimeInterval(-range.seconds)
  return history.filter { $0.date >= cutoff }
}

/// The existing sample closest to the inspected time. Always a real sample,
/// never an interpolated value.
public func nearestSample(
  at time: Date,
  in samples: [(date: Date, value: Double)]
) -> (date: Date, value: Double)? {
  samples.min(by: {
    abs($0.date.timeIntervalSince(time)) < abs($1.date.timeIntervalSince(time))
  })
}
