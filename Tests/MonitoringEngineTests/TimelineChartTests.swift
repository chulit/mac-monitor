import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Timeline chart engine math")
struct TimelineChartTests {
  @Test("Fractional metrics get the fixed 100 to 0 percent axis")
  func fractionalAxisTicks() {
    let ticks = yAxisTicks(values: [0.2, 0.8], fractional: true)
    #expect(ticks.map(\.value) == [1.0, 0.75, 0.5, 0.25, 0.0])
    #expect(ticks.map(\.label) == ["100%", "75%", "50%", "25%", "0%"])
  }

  @Test("Rate metrics get a nice-ceiling axis with rate labels")
  func rateAxisTicks() {
    // 3.2 MB/s rounds up to a 5 MB/s top.
    let ticks = yAxisTicks(values: [3_200_000], fractional: false)
    #expect(ticks.count == 5)
    #expect(ticks.first?.value == 5_000_000)
    #expect(ticks.first?.label == "4.8 MB/s")
    #expect(ticks.last?.value == 0)
  }

  @Test("Empty rate data falls back to a 1 unit axis")
  func rateAxisEmptyData() {
    let ticks = yAxisTicks(values: [], fractional: false)
    #expect(ticks.count == 5)
    #expect(ticks.first?.value == 1)
  }

  @Test("Time markers span the window evenly")
  func timeMarkersEvenlySpaced() {
    let start = Date(timeIntervalSince1970: 0)
    let end = start.addingTimeInterval(3_600)
    let markers = timeAxisMarkers(from: start, to: end, count: 7)
    #expect(markers.count == 7)
    #expect(markers.first == start)
    #expect(markers.last == end)
    #expect(markers[3] == start.addingTimeInterval(1_800))
  }

  @Test("Time markers reject nonsense input")
  func timeMarkersNonsense() {
    let now = Date(timeIntervalSince1970: 0)
    #expect(timeAxisMarkers(from: now, to: now, count: 5) == [])
    #expect(timeAxisMarkers(from: now, to: now.addingTimeInterval(10), count: 1) == [])
  }

  @Test("Range filtering keeps only samples inside the window")
  func rangeFiltering() {
    let now = Date(timeIntervalSince1970: 3_600)
    let history = (0..<10).map { index in
      (date: now.addingTimeInterval(TimeInterval(-index * 600)), value: Double(index))
    }
    let filtered = samples(in: .oneHour, endingAt: now, from: history)
    // Cutoff is exactly now - 3600s; the sample at index 6 sits on it.
    #expect(filtered.count == 7)
    #expect(filtered.allSatisfy { $0.date >= now.addingTimeInterval(-3_600) })
  }

  @Test("Nearest sample is the closest real sample")
  func nearestSamplePicksClosest() {
    let base = Date(timeIntervalSince1970: 1_000)
    let history = [
      (date: base, value: 0.1),
      (date: base.addingTimeInterval(10), value: 0.2),
      (date: base.addingTimeInterval(20), value: 0.3),
    ]
    let hit = nearestSample(at: base.addingTimeInterval(11), in: history)
    #expect(hit?.value == 0.2)
    #expect(nearestSample(at: base, in: []) == nil)
  }

  @Test("Timeline metric titles match the design")
  func metricTitles() {
    #expect(TimelineMetric.cpu.title == "CPU Usage")
    #expect(TimelineMetric.cpu.pillTitle == "CPU")
    #expect(TimelineMetric.network.title == "Network Activity")
    #expect(TimelineMetric.cpu.isFractional)
    #expect(!TimelineMetric.network.isFractional)
  }
}
