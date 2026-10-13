import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Overview cards engine logic")
struct OverviewCardsTests {
  private func makeIncident(source: Incident.Source) -> Incident {
    Incident(
      startedAt: Date(timeIntervalSince1970: 1_000),
      peakAt: Date(timeIntervalSince1970: 1_060),
      recoveredAt: nil,
      source: source
    )
  }

  @Test("Incident category follows the metric")
  func incidentCategoryMapping() {
    #expect(incidentCategory(metric: "cpu") == .cpu)
    #expect(incidentCategory(metric: "memory") == .memory)
    #expect(incidentCategory(metric: "disk") == .disk)
    #expect(incidentCategory(metric: "network") == .network)
    #expect(incidentCategory(metric: "CPU") == .cpu)
    #expect(incidentCategory(metric: "temperature") == .unknown)
    #expect(incidentCategory(metric: nil) == .unknown)
  }

  @Test("Incident titles match the popover wording")
  func incidentTitles() {
    let rule = makeIncident(source: .rule(version: "v1"))
    #expect(incidentTitle(incident: rule, metric: "cpu") == "High CPU Usage")
    #expect(incidentTitle(incident: rule, metric: nil) == "High METRIC Usage")
    let baseline = makeIncident(source: .baseline(version: "v1"))
    #expect(incidentTitle(incident: baseline, metric: "cpu") == "Unusual behavior")
  }

  @Test("Relative time uses the compact buckets")
  func relativeTimeBuckets() {
    let now = Date(timeIntervalSince1970: 10_000)
    #expect(relativeTimeString(from: now.addingTimeInterval(-30), to: now) == "just now")
    #expect(relativeTimeString(from: now.addingTimeInterval(-300), to: now) == "5m ago")
    #expect(relativeTimeString(from: now.addingTimeInterval(-7_200), to: now) == "2h ago")
    #expect(relativeTimeString(from: now.addingTimeInterval(-259_200), to: now) == "3d ago")
  }

  @Test("Top processes keep the latest sample per process, sorted")
  func topProcessesLatestAndSorted() {
    let base = Date(timeIntervalSince1970: 5_000)
    let safari = Process(id: "1", parent: nil, name: "Safari")
    let xcode = Process(id: "2", parent: nil, name: "Xcode")
    let samples = [
      ProcessSample(timestamp: base, process: safari, metric: "cpu", value: 0.1),
      // A newer, hotter reading for Safari wins over the stale one.
      ProcessSample(timestamp: base.addingTimeInterval(5), process: safari, metric: "cpu", value: 0.6),
      ProcessSample(timestamp: base, process: xcode, metric: "cpu", value: 0.3),
      // Wrong metric is ignored.
      ProcessSample(timestamp: base, process: xcode, metric: "memory", value: 0.9),
    ]
    let top = topProcesses(samples: samples, metric: "cpu", limit: 5)
    #expect(top.count == 2)
    #expect(top[0].process.name == "Safari")
    #expect(top[0].share == 0.6)
    #expect(top[1].process.name == "Xcode")
  }

  @Test("Top processes respect the limit and clamp shares")
  func topProcessesLimitAndClamp() {
    let base = Date(timeIntervalSince1970: 5_000)
    let samples = (0..<10).map { index in
      ProcessSample(
        timestamp: base,
        process: Process(id: "\(index)", parent: nil, name: "P\(index)"),
        metric: "cpu",
        value: Double(index) / 10 + 5
      )
    }
    let top = topProcesses(samples: samples, metric: "cpu", limit: 3)
    #expect(top.count == 3)
    #expect(top.allSatisfy { $0.share <= 1 })
    #expect(topProcesses(samples: [], metric: "cpu", limit: 3) == [])
  }
}
