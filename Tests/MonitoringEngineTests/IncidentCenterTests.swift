import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Incident center")
struct IncidentCenterTests {
  private var now: Date { Date(timeIntervalSince1970: 100_000) }

  private func incident(
    startedAgo: TimeInterval,
    recoveredAgo: TimeInterval? = nil
  ) -> Incident {
    let startedAt = now.addingTimeInterval(-startedAgo)
    return Incident(
      startedAt: startedAt,
      peakAt: startedAt.addingTimeInterval(60),
      recoveredAt: recoveredAgo.map { now.addingTimeInterval(-$0) },
      source: .rule(version: "v1")
    )
  }

  private func timeline(
    for incident: Incident,
    values: [Double],
    markers: [TimelineMarker] = []
  ) -> IncidentTimeline {
    let samples = values.enumerated().map { index, value in
      Sample(
        timestamp: incident.startedAt.addingTimeInterval(Double(index) * 60),
        availability: .available,
        value: value,
        metric: "cpu"
      )
    }
    return IncidentTimeline(
      incident: incident,
      metricSamples: samples,
      gaps: [],
      markers: markers,
      ruleVersion: "v1",
      baselineVersion: nil,
      relevantProcesses: [
        ProcessRelevance(
          process: Process(id: "1", parent: nil, name: "WindowServer"),
          contribution: 0.68,
          reasons: ["top contributor"]
        )
      ]
    )
  }

  @Test("Status filter splits active and resolved")
  func statusFilter() {
    let active = incident(startedAgo: 300)
    let resolved = incident(startedAgo: 900, recoveredAgo: 100)
    let all = [active, resolved]
    #expect(filteredIncidents(all, status: .all, range: .week, now: now).count == 2)
    #expect(filteredIncidents(all, status: .active, range: .week, now: now) == [active])
    #expect(filteredIncidents(all, status: .resolved, range: .week, now: now) == [resolved])
  }

  @Test("Date range drops old incidents and sorts newest first")
  func dateRangeFilter() {
    let recent = incident(startedAgo: 3_600)
    let old = incident(startedAgo: 200_000)
    let filtered = filteredIncidents([old, recent], status: .all, range: .day, now: now)
    #expect(filtered == [recent])
  }

  @Test("Summary computes peak, average, and affected processes")
  func summaryMath() {
    let inc = incident(startedAgo: 600)
    let summary = incidentSummary(
      incident: inc,
      timeline: timeline(for: inc, values: [0.5, 0.9, 0.7])
    )
    #expect(summary.peak == 0.9)
    #expect(abs((summary.average ?? 0) - 0.7) < 1e-9)
    #expect(summary.isOngoing == true)
    #expect(summary.affectedProcesses == 1)
    #expect(summary.primaryMetric == "cpu")
  }

  @Test("Summary without a timeline yields nils, never zeros")
  func summaryWithoutTimeline() {
    let summary = incidentSummary(incident: incident(startedAgo: 60), timeline: nil)
    #expect(summary.peak == nil)
    #expect(summary.average == nil)
    #expect(summary.affectedProcesses == 0)
  }

  @Test("Event trail follows markers and ends with the live status")
  func eventTrail() {
    let inc = incident(startedAgo: 600)
    let markers = [
      TimelineMarker(timestamp: inc.startedAt, kind: .started),
      TimelineMarker(timestamp: inc.peakAt, kind: .peak),
    ]
    let events = incidentEvents(
      incident: inc,
      timeline: timeline(for: inc, values: [0.5, 0.9], markers: markers),
      now: now
    )
    #expect(events.count == 3)
    #expect(events[0].kind == .detected)
    #expect(events[1].kind == .peak)
    #expect(events[1].text.contains("90%"))
    #expect(events[2].kind == .ongoing)
    #expect(events == events.sorted { $0.timestamp < $1.timestamp })
  }

  @Test("Recovered incidents end with a recovery event")
  func recoveredTrail() {
    let inc = incident(startedAgo: 900, recoveredAgo: 100)
    let markers = [
      TimelineMarker(timestamp: inc.startedAt, kind: .started),
      TimelineMarker(timestamp: inc.recoveredAt!, kind: .recovered),
    ]
    let events = incidentEvents(
      incident: inc,
      timeline: timeline(for: inc, values: [0.8], markers: markers),
      now: now
    )
    #expect(events.last?.kind == .recovered)
    #expect(!events.contains { $0.kind == .ongoing })
  }

  @Test("Duration formats compactly")
  func durationFormat() {
    #expect(formatDuration(45) == "45s")
    #expect(formatDuration(204) == "3m 24s")
    #expect(formatDuration(7_500) == "2h 5m")
  }
}
