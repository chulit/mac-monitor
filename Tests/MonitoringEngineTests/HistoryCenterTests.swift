import Foundation
import Testing

@testable import MonitoringEngine

@Suite("History center")
struct HistoryCenterTests {
  private var now: Date { Date(timeIntervalSince1970: 500_000) }

  private func sample(
    metric: String, value: Double, at date: Date
  ) -> Sample {
    Sample(timestamp: date, availability: .available, value: value, metric: metric)
  }

  private func incident(
    startedAgo: TimeInterval, duration: TimeInterval, recovered: Bool = true
  ) -> Incident {
    let startedAt = now.addingTimeInterval(-startedAgo)
    return Incident(
      startedAt: startedAt,
      peakAt: startedAt.addingTimeInterval(duration / 2),
      recoveredAt: recovered ? startedAt.addingTimeInterval(duration) : nil,
      source: .rule(version: "v1")
    )
  }

  private var details: [Sample] {
    var samples: [Sample] = []
    // 3 days of hourly CPU samples, one spike 2 days ago.
    for hour in 0..<72 {
      let date = now.addingTimeInterval(-Double(hour) * 3600)
      let value = hour == 48 ? 0.92 : 0.2 + Double(hour % 5) * 0.02
      samples.append(sample(metric: "cpu", value: value, at: date))
      samples.append(sample(metric: "memory", value: 0.6, at: date))
    }
    return samples
  }

  @Test("Activity series caps points and keeps the spike")
  func activitySeriesBucketing() {
    let series = activitySeries(
      details: details, summaries: [], metric: "cpu", range: .week, now: now, maxPoints: 24
    )
    #expect(series.count <= 24)
    #expect(!series.isEmpty)
    let peak = series.max { $0.value < $1.value }
    #expect((peak?.value ?? 0) > 0.5)
  }

  @Test("Activity series merges summary averages for old spans")
  func activitySeriesSummaries() {
    let summary = SampleSummary(
      metric: "cpu",
      start: now.addingTimeInterval(-2_000_000),
      end: now.addingTimeInterval(-1_900_000),
      count: 100, min: 0.1, max: 0.5, average: 0.3, variation: 0.1,
      thresholdExceededDuration: 0, incidentCount: 0
    )
    let series = activitySeries(
      details: [], summaries: [summary], metric: "cpu", range: .month, now: now
    )
    #expect(series.count == 1)
    #expect(abs(series[0].value - 0.3) < 1e-9)
  }

  @Test("Historical incidents infer metric, peak, and severity")
  func historicalIncidentEnrichment() throws {
    let inc = incident(startedAgo: 48 * 3600, duration: 600)
    let items = historicalIncidents(incidents: [inc], details: details, now: now)
    #expect(items.count == 1)
    let item = try #require(items.first)
    #expect(item.metric == "cpu")
    #expect(abs((item.peak ?? 0) - 0.92) < 1e-9)
    #expect(item.severity == .high)
    #expect(item.title == "High CPU Usage")
  }

  @Test("Dedupe prefers the recovered record")
  func historicalIncidentDedupe() throws {
    let startedAt = now.addingTimeInterval(-3600)
    let active = Incident(
      startedAt: startedAt, peakAt: startedAt.addingTimeInterval(60),
      recoveredAt: nil, source: .rule(version: "v1")
    )
    let recovered = Incident(
      startedAt: startedAt, peakAt: startedAt.addingTimeInterval(60),
      recoveredAt: startedAt.addingTimeInterval(300), source: .rule(version: "v1")
    )
    let items = historicalIncidents(incidents: [active, recovered], details: [], now: now)
    #expect(items.count == 1)
    #expect(try #require(items.first).incident.recoveredAt != nil)
  }

  @Test("Severity filter and search narrow the table")
  func filtering() throws {
    let high = incident(startedAgo: 48 * 3600, duration: 600)
    let calm = incident(startedAgo: 3600, duration: 600)
    let items = historicalIncidents(incidents: [high, calm], details: details, now: now)
    #expect(items.count == 2)
    let onlyHigh = filterHistoricalIncidents(items, severity: .high, query: "", sort: .newest)
    #expect(onlyHigh.count == 1)
    let searched = filterHistoricalIncidents(items, severity: .all, query: "cpu", sort: .newest)
    #expect(searched.count == 2)
    let oldest = filterHistoricalIncidents(items, severity: .all, query: "", sort: .oldest)
    #expect(try #require(oldest.first).incident.startedAt < try #require(oldest.last).incident.startedAt)
  }

  @Test("Historical timeline wraps the incident with padding and markers")
  func historicalTimelineWindow() {
    let inc = incident(startedAgo: 3600, duration: 600)
    let timeline = historicalTimeline(incident: inc, details: details, now: now)
    #expect(timeline.markers.count == 3)
    #expect(!timeline.metricSamples.isEmpty)
    #expect(timeline.metricSamples.first!.timestamp < inc.startedAt)
  }

  @Test("System context picks the nearest readings")
  func systemContextNearest() {
    let inc = incident(startedAgo: 48 * 3600, duration: 600)
    let context = systemContext(incident: inc, details: details)
    #expect(abs((context.memoryFraction ?? 0) - 0.6) < 1e-9)
    #expect(context.networkRate == nil)
  }

  @Test("Narrative states facts without inventing attribution")
  func narrative() {
    let inc = incident(startedAgo: 3600, duration: 204)
    let items = historicalIncidents(incidents: [inc], details: details, now: now)
    let text = incidentNarrative(item: try! items.first!, now: now)
    #expect(text.contains("3m 24s"))
    #expect(text.contains("recovered"))
  }
}
