import Foundation
import Testing

@testable import MonitoringEngine

private func investigationPolicy(maximumHighDetailDuration: TimeInterval = 600) -> ObservationPolicy {
  ObservationPolicy(
    budgetLimit: 1.0,
    criticalMetrics: ["cpu"],
    normalInterval: 1.0,
    reducedInterval: 5.0,
    highDetailInterval: 0.5,
    overBudgetEvaluationsToDegrade: 2,
    underBudgetEvaluationsToRecover: 2,
    maximumHighDetailDuration: maximumHighDetailDuration,
    highDetailWarningBeforeEnd: 60
  )
}

@Suite("Overview header engine support")
struct OverviewHeaderTests {
  @Test("Ending a high-detail session early returns to normal")
  func endHighDetailEarly() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let pipeline = Pipeline(clock: clock, rules: [], observation: investigationPolicy())
    pipeline.requestHighDetail(duration: 600)
    let started = pipeline.evaluate([])
    #expect(started.observation?.mode == .highDetail(remaining: 600, limit: 600, warning: false))

    pipeline.endHighDetail()
    let ended = pipeline.evaluate([])
    #expect(ended.observation?.mode == .normal)
    let transition = try #require(ended.observationTransitions.first)
    #expect(transition.timestamp == start)
    #expect(transition.from == .highDetail)
    #expect(transition.to == .normal)
    #expect(transition.reason == "high-detail session ended early")
  }

  @Test("Ending with no active session is a no-op")
  func endHighDetailWithoutSessionIsNoop() {
    let clock = ControlledClock(startingAt: Date(timeIntervalSince1970: 0))
    let pipeline = Pipeline(clock: clock, rules: [], observation: investigationPolicy())
    pipeline.endHighDetail()
    let evaluation = pipeline.evaluate([])
    #expect(evaluation.observation?.mode == .normal)
    #expect(evaluation.observationTransitions.isEmpty)
  }

  @Test("Ending twice records a single transition")
  func endHighDetailTwiceIsIdempotent() throws {
    let clock = ControlledClock(startingAt: Date(timeIntervalSince1970: 0))
    let pipeline = Pipeline(clock: clock, rules: [], observation: investigationPolicy())
    pipeline.requestHighDetail(duration: 600)
    _ = pipeline.evaluate([])
    pipeline.endHighDetail()
    pipeline.endHighDetail()
    let ended = pipeline.evaluate([])
    #expect(ended.observation?.mode == .normal)
    #expect(ended.observationTransitions.count == 1)
  }

  @Test("Time ranges default to the last hour with increasing windows")
  func timeRangeDefaultsAndOrdering() {
    #expect(OverviewTimeRange.default == .oneHour)
    let seconds = OverviewTimeRange.allCases.map(\.seconds)
    #expect(seconds == [900, 1_800, 3_600, 21_600, 86_400])
    #expect(Set(seconds).count == seconds.count)
  }

  @Test("Every time range has a human-readable title")
  func timeRangeTitles() {
    #expect(OverviewTimeRange.fifteenMinutes.title == "Last 15 Minutes")
    #expect(OverviewTimeRange.thirtyMinutes.title == "Last 30 Minutes")
    #expect(OverviewTimeRange.oneHour.title == "Last 1 Hour")
    #expect(OverviewTimeRange.sixHours.title == "Last 6 Hours")
    #expect(OverviewTimeRange.twentyFourHours.title == "Last 24 Hours")
  }
}
