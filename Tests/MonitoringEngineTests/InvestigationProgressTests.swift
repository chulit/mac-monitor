import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Investigation progress math")
struct InvestigationProgressTests {
  private var now: Date { Date(timeIntervalSince1970: 100_000) }

  @Test("Fraction is elapsed over limit")
  func fractionMath() {
    // 1296 of 1800 seconds elapsed -> 72%.
    let progress = investigationProgress(
      remaining: 504, limit: 1_800, incidents: [], now: now
    )
    #expect(abs(progress.fraction - 0.72) < 1e-9)
    #expect(progress.phases.count == 3)
    #expect(progress.completedCount == 1)
  }

  @Test("Active phase shows the live percent and elapsed seconds")
  func activePhaseDetail() {
    let progress = investigationProgress(
      remaining: 504, limit: 1_800, incidents: [], now: now
    )
    let analyzing = progress.phases[1]
    #expect(analyzing.state == .active)
    #expect(analyzing.statusText == "72%")
    #expect(analyzing.durationText == "1296s")
    #expect(analyzing.progress == progress.fraction)
  }

  @Test("Detection completes only for incidents inside the session")
  func detectionPhase() {
    let sessionIncident = Incident(
      startedAt: now.addingTimeInterval(-100),
      peakAt: now.addingTimeInterval(-90),
      recoveredAt: nil,
      source: .rule(version: "v1")
    )
    let withIncident = investigationProgress(
      remaining: 504, limit: 1_800, incidents: [sessionIncident], now: now
    )
    #expect(withIncident.phases[2].state == .completed)
    #expect(withIncident.phases[2].statusText == "Completed")
    #expect(withIncident.completedCount == 2)

    let oldIncident = Incident(
      startedAt: now.addingTimeInterval(-10_000),
      peakAt: now.addingTimeInterval(-9_990),
      recoveredAt: now.addingTimeInterval(-9_000),
      source: .rule(version: "v1")
    )
    let withoutIncident = investigationProgress(
      remaining: 504, limit: 1_800, incidents: [oldIncident], now: now
    )
    #expect(withoutIncident.phases[2].state == .pending)
    #expect(withoutIncident.phases[2].statusText == "Pending")
    #expect(withoutIncident.completedCount == 1)
  }

  @Test("Fraction clamps outside the session window")
  func fractionClamping() {
    let over = investigationProgress(remaining: 2_000, limit: 1_800, incidents: [], now: now)
    #expect(over.fraction == 0)
    let under = investigationProgress(remaining: -10, limit: 1_800, incidents: [], now: now)
    #expect(under.fraction == 1)
  }
}
