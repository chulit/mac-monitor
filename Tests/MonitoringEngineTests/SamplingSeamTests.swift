import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Sampling seam")
struct SamplingSeamTests {
  @Test("Normal samples flow through the seam and raise no incidents")
  func normalStreamRaisesNoIncidents() {
    let clock = ControlledClock(startingAt: Date(timeIntervalSince1970: 0))
    let stream = SyntheticStream.scenario(.normal, startingAt: clock.now(), spacing: 1.0)
    let pipeline = Pipeline(clock: clock)
    let evaluation = pipeline.evaluate(stream.samples)
    #expect(evaluation.incidents.isEmpty)
  }

  @Test("Unavailable samples are reported as gaps and never filled in")
  func unavailableSamplesAreGaps() {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let stream = SyntheticStream.scenario(.withGaps, startingAt: clock.now(), spacing: 1.0)
    let pipeline = Pipeline(clock: clock)
    let evaluation = pipeline.evaluate(stream.samples)
    #expect(evaluation.incidents.isEmpty)
    #expect(
      evaluation.gaps.map(\.timestamp)
        == [start.addingTimeInterval(3), start.addingTimeInterval(7)]
    )
  }

  @Test("The same stream replays to an identical evaluation")
  func replayIsDeterministic() {
    let clock = ControlledClock(startingAt: Date(timeIntervalSince1970: 0))
    let stream = SyntheticStream.scenario(.withGaps, startingAt: clock.now(), spacing: 1.0)
    let pipeline = Pipeline(clock: clock)
    let first = pipeline.evaluate(stream.samples)
    let second = pipeline.evaluate(stream.samples)
    #expect(first == second)
  }

  @Test("Sustained critical pressure opens one incident with start, peak, and recovery")
  func sustainedPressureOpensIncident() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let stream = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let evaluation = pipeline.evaluate(stream.samples)
    #expect(evaluation.incidents.count == 1)
    let incident = try #require(evaluation.incidents.first)
    #expect(incident.startedAt == start.addingTimeInterval(5))
    #expect(incident.peakAt == start.addingTimeInterval(9))
    #expect(incident.recoveredAt == start.addingTimeInterval(15))
  }

  @Test("A momentary spike raises no incident")
  func momentarySpikeRaisesNoIncident() {
    let clock = ControlledClock(startingAt: Date(timeIntervalSince1970: 0))
    let stream = SyntheticStream.scenario(.spike, startingAt: clock.now(), spacing: 1.0)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let evaluation = pipeline.evaluate(stream.samples)
    #expect(evaluation.incidents.isEmpty)
  }

  @Test("Extended history updates the open incident instead of duplicating it")
  func extendedHistoryUpdatesOpenIncident() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let stream = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let partial = pipeline.evaluate(Array(stream.samples.prefix(13)))
    #expect(partial.incidents.count == 1)
    let partialIncident = try #require(partial.incidents.first)
    #expect(partialIncident.recoveredAt == nil)
    let full = pipeline.evaluate(stream.samples)
    #expect(full.incidents.count == 1)
    let fullIncident = try #require(full.incidents.first)
    #expect(fullIncident.startedAt == partialIncident.startedAt)
    #expect(fullIncident.recoveredAt == start.addingTimeInterval(15))
  }

  @Test("An excursion inside cooldown opens no new incident")
  func cooldownSuppressesRepeat() {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let samples = episodeSamples(start: start, count: 40, criticalRanges: [5..<11, 20..<26])
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let evaluation = pipeline.evaluate(samples)
    #expect(evaluation.incidents.count == 1)
  }

  @Test("An excursion after cooldown opens a new incident")
  func afterCooldownNewIncident() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let samples = episodeSamples(start: start, count: 60, criticalRanges: [5..<11, 45..<51])
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let evaluation = pipeline.evaluate(samples)
    #expect(evaluation.incidents.count == 2)
    let second = try #require(evaluation.incidents.last)
    #expect(second.startedAt == start.addingTimeInterval(45))
    #expect(second.recoveredAt == start.addingTimeInterval(51))
  }

  @Test("An excursion starting inside cooldown stays suppressed past the cooldown end")
  func suppressedExcursionOutlivingCooldown() {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let samples = episodeSamples(start: start, count: 60, criticalRanges: [5..<11, 20..<51])
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let evaluation = pipeline.evaluate(samples)
    #expect(evaluation.incidents.count == 1)
  }

  @Test("Baseline learns normal samples and publishes promotion history")
  func baselineLearnsAndPromotes() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let baselineConfig = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 20,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 600,
      algorithmVersion: "1"
    )
    let pipeline = Pipeline(clock: clock, rules: [], baseline: baselineConfig)
    let stream = SyntheticStream.scenario(.normal, startingAt: start, spacing: 1.0)
    let evaluation = pipeline.evaluate(stream.samples)
    #expect(evaluation.incidents.isEmpty)
    let baseline = try #require(pipeline.baseline)
    #expect(baseline.status == .limited)
    #expect(baseline.qualifyingSamples == 10)
    #expect(baseline.mean == 0.3)
    #expect(baseline.history.count == 1)
    let change = try #require(baseline.history.first)
    #expect(change.time == start)
    #expect(change.reason == "promoted to active")
    #expect(change.algorithmVersion == "1")
    #expect(change.qualifyingSamples == 5)
  }

  @Test("Incident spans are excluded from baseline learning")
  func incidentSpansExcludedFromLearning() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let config = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 100,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 600,
      algorithmVersion: "1"
    )
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule], baseline: config)
    let calm = SyntheticStream.scenario(.normal, startingAt: start, spacing: 1.0)
    _ = pipeline.evaluate(calm.samples)
    let storm = SyntheticStream.scenario(
      .sustainedPressure,
      startingAt: start.addingTimeInterval(100),
      spacing: 1.0
    )
    let evaluation = pipeline.evaluate(storm.samples)
    #expect(evaluation.incidents.count == 1)
    let baseline = try #require(pipeline.baseline)
    #expect(baseline.qualifyingSamples == 22)
    #expect(baseline.mean == 0.3)
  }

  @Test("Sustained contextual deviation opens an incident without contaminating the baseline")
  func contextualDeviationOpensIncident() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let config = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 100,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 600,
      algorithmVersion: "1"
    )
    let pipeline = Pipeline(clock: clock, rules: [], baseline: config)
    let base: [Double] = [
      0.28, 0.31, 0.30, 0.29, 0.32, 0.30, 0.27, 0.31, 0.30, 0.29,
      0.30, 0.32, 0.28, 0.30, 0.31, 0.29, 0.30, 0.30, 0.28, 0.31,
    ]
    let calm = base.enumerated().map { index, value in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: value
      )
    }
    _ = pipeline.evaluate(calm)
    let shiftStart = start.addingTimeInterval(100)
    let shifted = (0..<10).map { index in
      Sample(
        timestamp: shiftStart.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.9
      )
    }
    let backToNormal = (10..<20).map { index in
      Sample(
        timestamp: shiftStart.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.3
      )
    }
    let evaluation = pipeline.evaluate(shifted + backToNormal)
    #expect(evaluation.incidents.count == 1)
    let incident = try #require(evaluation.incidents.first)
    #expect(incident.startedAt == shiftStart)
    #expect(incident.recoveredAt == shiftStart.addingTimeInterval(10))
    let baseline = try #require(pipeline.baseline)
    #expect(baseline.qualifyingSamples == 30)
    #expect(baseline.mean < 0.35)
  }

  @Test("Rules fire on a fresh baseline with no duplicate deviation incident")
  func rulesFireWhileBaselineLearning() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let config = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 20,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 600,
      algorithmVersion: "1"
    )
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule], baseline: config)
    let stream = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0)
    let evaluation = pipeline.evaluate(stream.samples)
    #expect(evaluation.incidents.count == 1)
    let baseline = try #require(pipeline.baseline)
    #expect(baseline.status == .limited)
    #expect(baseline.mean == 0.3)
  }

  @Test("A baseline with no recent qualifying samples reports stale")
  func baselineGoesStale() throws {
    let start = Date(timeIntervalSince1970: 0)
    var clock = ControlledClock(startingAt: start)
    let config = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 20,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 600,
      algorithmVersion: "1"
    )
    let pipeline = Pipeline(clock: clock, rules: [], baseline: config)
    let stream = SyntheticStream.scenario(.normal, startingAt: start, spacing: 1.0)
    _ = pipeline.evaluate(stream.samples)
    let fresh = try #require(pipeline.baseline)
    #expect(fresh.status == .limited)
    clock.advance(by: 3600)
    _ = pipeline.evaluate([])
    let stale = try #require(pipeline.baseline)
    #expect(stale.status == .stale)
    #expect(stale.qualifyingSamples == 10)
  }

  @Test("A mature baseline reports stable")
  func matureBaselineReportsStable() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let config = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 20,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 600,
      algorithmVersion: "1"
    )
    let pipeline = Pipeline(clock: clock, rules: [], baseline: config)
    let first = SyntheticStream.scenario(.normal, startingAt: start, spacing: 1.0)
    _ = pipeline.evaluate(first.samples)
    let second = SyntheticStream.scenario(
      .normal,
      startingAt: start.addingTimeInterval(100),
      spacing: 1.0
    )
    _ = pipeline.evaluate(second.samples)
    let baseline = try #require(pipeline.baseline)
    #expect(baseline.status == .stable)
    #expect(baseline.qualifyingSamples == 20)
  }

  private func episodeSamples(start: Date, count: Int, criticalRanges: [Range<Int>]) -> [Sample] {    (0..<count).map { index in
      let critical = criticalRanges.contains { $0.contains(index) }
      return Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: critical ? 0.9 : 0.3
      )
    }
  }
}
