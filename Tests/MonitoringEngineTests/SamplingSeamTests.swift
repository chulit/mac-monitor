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
    let baseline = try #require(pipeline.baseline(for: "cpu"))
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
    let baseline = try #require(pipeline.baseline(for: "cpu"))
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
    let baseline = try #require(pipeline.baseline(for: "cpu"))
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
    let baseline = try #require(pipeline.baseline(for: "cpu"))
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
    let fresh = try #require(pipeline.baseline(for: "cpu"))
    #expect(fresh.status == .limited)
    clock.advance(by: 3600)
    _ = pipeline.evaluate([])
    let stale = try #require(pipeline.baseline(for: "cpu"))
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
    let baseline = try #require(pipeline.baseline(for: "cpu"))
    #expect(baseline.status == .stable)
    #expect(baseline.qualifyingSamples == 20)
  }

  @Test("Baselines learn each metric separately")
  func baselinesLearnPerMetric() throws {
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
    let cpu = (0..<10).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.3,
        metric: "cpu"
      )
    }
    let memory = (0..<10).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.5,
        metric: "memory"
      )
    }
    let evaluation = pipeline.evaluate(cpu + memory)
    #expect(evaluation.incidents.isEmpty)
    let cpuBaseline = try #require(pipeline.baseline(for: "cpu"))
    #expect(cpuBaseline.qualifyingSamples == 10)
    #expect(cpuBaseline.mean == 0.3)
    #expect(cpuBaseline.status == .limited)
    let memoryBaseline = try #require(pipeline.baseline(for: "memory"))
    #expect(memoryBaseline.qualifyingSamples == 10)
    #expect(memoryBaseline.mean == 0.5)
  }

  @Test("Each incident carries a synchronized timeline with provenance")
  func incidentCarriesTimeline() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let memory = (0..<22).map { index in
      let missing = index == 8 || index == 9
      return Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: missing ? .unavailable : .available,
        value: missing ? nil : 0.5,
        metric: "memory"
      )
    }
    let evaluation = pipeline.evaluate(cpu + memory)
    #expect(evaluation.incidents.count == 1)
    #expect(evaluation.timelines.count == 1)
    let incident = try #require(evaluation.incidents.first)
    let timeline = try #require(evaluation.timelines.first)
    #expect(timeline.incident == incident)
    let end = try #require(incident.recoveredAt)
    #expect(Set(timeline.metricSamples.map(\.metric)) == ["cpu", "memory"])
    #expect(timeline.metricSamples.count == 20)
    #expect(
      timeline.metricSamples.allSatisfy {
        $0.timestamp >= incident.startedAt && $0.timestamp <= end
      }
    )
    #expect(
      timeline.gaps.map(\.timestamp)
        == [start.addingTimeInterval(8), start.addingTimeInterval(9)]
    )
    #expect(
      timeline.markers
        == [
          TimelineMarker(timestamp: start.addingTimeInterval(5), kind: .started),
          TimelineMarker(timestamp: start.addingTimeInterval(9), kind: .peak),
          TimelineMarker(timestamp: start.addingTimeInterval(15), kind: .recovered),
        ]
    )
    #expect(timeline.ruleVersion == "1")
    #expect(timeline.baselineVersion == nil)
  }

  @Test("Baseline-raised incidents carry the baseline version")
  func baselineIncidentCarriesBaselineVersion() throws {
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
    #expect(evaluation.timelines.count == 1)
    let timeline = try #require(evaluation.timelines.first)
    #expect(timeline.ruleVersion == nil)
    #expect(timeline.baselineVersion == "1")
  }

  @Test("Incident timelines rank relevant processes with stated reasons")
  func timelinesRankRelevantProcesses() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let alpha = Process(id: "a", parent: nil, name: "Alpha")
    let beta = Process(id: "b", parent: "d", name: "Beta")
    let gamma = Process(id: "c", parent: nil, name: "Gamma")
    let delta = Process(id: "d", parent: nil, name: "Delta")
    var activity: [ProcessSample] = []
    for index in 0..<5 {
      activity.append(
        ProcessSample(
          timestamp: start.addingTimeInterval(TimeInterval(index)),
          process: alpha,
          metric: "cpu",
          value: 0.9
        )
      )
      activity.append(
        ProcessSample(
          timestamp: start.addingTimeInterval(TimeInterval(index)),
          process: delta,
          metric: "cpu",
          value: 0.1
        )
      )
    }
    for index in 5..<16 {
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      activity.append(ProcessSample(timestamp: timestamp, process: alpha, metric: "cpu", value: 0.5))
      activity.append(ProcessSample(timestamp: timestamp, process: beta, metric: "cpu", value: 0.25))
      activity.append(ProcessSample(timestamp: timestamp, process: gamma, metric: "cpu", value: 0.0))
    }
    let evaluation = pipeline.evaluate(cpu, processes: activity)
    #expect(evaluation.incidents.count == 1)
    let timeline = try #require(evaluation.timelines.first)
    #expect(timeline.relevantProcesses.count == 3)
    let first = try #require(timeline.relevantProcesses.first)
    #expect(first.process.id == "a")
    #expect(abs(first.contribution - 0.6667) < 0.001)
    #expect(first.reasons == ["largest resource share during incident"])
    let second = timeline.relevantProcesses[1]
    #expect(second.process.id == "b")
    #expect(abs(second.contribution - 0.3333) < 0.001)
    #expect(second.reasons == ["elevated resource share during incident"])
    let third = timeline.relevantProcesses[2]
    #expect(third.process.id == "d")
    #expect(third.contribution == 0)
    #expect(third.reasons == ["ancestor of elevated process Beta"])
    #expect(
      timeline.relevantProcesses.allSatisfy { relevance in
        relevance.reasons.allSatisfy { !$0.lowercased().contains("caus") }
      }
    )
  }

  @Test("Cyclic parent links terminate instead of hanging")
  func cyclicParentsTerminate() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let first = Process(id: "x", parent: "y", name: "Ex")
    let second = Process(id: "y", parent: "x", name: "Why")
    let activity = (5..<16).map { index in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        ProcessSample(timestamp: timestamp, process: first, metric: "cpu", value: 0.5),
        ProcessSample(timestamp: timestamp, process: second, metric: "cpu", value: 0.5),
      ]
    }.flatMap { $0 }
    let evaluation = pipeline.evaluate(cpu, processes: activity)
    let timeline = try #require(evaluation.timelines.first)
    #expect(timeline.relevantProcesses.count == 2)
  }

  @Test("Budget pressure degrades noncritical metrics while preserving critical sampling")
  func budgetPressureDegradesNoncriticalFirst() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let pipeline = Pipeline(clock: clock, rules: [], observation: policy)
    let batch = (0..<10).flatMap { index -> [Sample] in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        Sample(timestamp: timestamp, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: timestamp, availability: .available, value: 0.5, metric: "memory"),
      ]
    }
    let steady = pipeline.evaluate(batch, usage: ResourceUsage(used: 2.0))
    #expect(steady.observation?.mode == .normal)
    #expect(steady.observationTransitions.isEmpty)
    let degraded = pipeline.evaluate(batch, usage: ResourceUsage(used: 2.0))
    #expect(
      degraded.observation?.mode
        == .reduced(reason: "over resource budget", affectedMetrics: ["memory"])
    )
    #expect(degraded.observation?.intervalsByMetric == ["cpu": 1.0, "memory": 5.0])
    #expect(degraded.observation?.observedIntervals == [1.0])
    #expect(degraded.observationTransitions.count == 1)
    let transition = try #require(degraded.observationTransitions.first)
    #expect(transition.from == .normal)
    #expect(transition.to == .reduced)
    #expect(transition.reason == "over resource budget")
    #expect(transition.affectedMetrics == ["memory"])
  }

  @Test("Hysteresis prevents flapping and recovers quality gradually")
  func hysteresisPreventsFlapping() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let pipeline = Pipeline(clock: clock, rules: [], observation: policy)
    let batch = (0..<10).flatMap { index -> [Sample] in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        Sample(timestamp: timestamp, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: timestamp, availability: .available, value: 0.5, metric: "memory"),
      ]
    }
    let over = ResourceUsage(used: 2.0)
    let under = ResourceUsage(used: 0.5)
    #expect(pipeline.evaluate(batch, usage: over).observation?.mode == .normal)
    #expect(pipeline.evaluate(batch, usage: under).observation?.mode == .normal)
    #expect(pipeline.evaluate(batch, usage: over).observation?.mode == .normal)
    #expect(pipeline.evaluate(batch, usage: over).observation?.mode != .normal)
    #expect(pipeline.evaluate(batch, usage: under).observation?.mode != .normal)
    let recovered = pipeline.evaluate(batch, usage: under)
    #expect(recovered.observation?.mode == .normal)
    #expect(recovered.observationTransitions.count == 1)
    let transition = try #require(recovered.observationTransitions.first)
    #expect(transition.from == .reduced)
    #expect(transition.to == .normal)
    #expect(transition.reason == "within resource budget")
  }

  @Test("Reduced monitoring shows its reason on the incident timeline")
  func reducedIndicatorOnTimeline() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule], observation: policy)
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let memory = (0..<22).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.5,
        metric: "memory"
      )
    }
    let over = ResourceUsage(used: 2.0)
    let first = pipeline.evaluate(cpu + memory, usage: over)
    #expect(first.observation?.mode == .normal)
    clock.advance(by: 10)
    let second = pipeline.evaluate(cpu + memory, usage: over)
    #expect(
      second.observation?.mode
        == .reduced(reason: "over resource budget", affectedMetrics: ["memory"])
    )
    let timeline = try #require(second.timelines.first)
    #expect(timeline.observationTransitions.count == 1)
    let transition = try #require(timeline.observationTransitions.first)
    #expect(transition.timestamp == start.addingTimeInterval(10))
    #expect(transition.reason == "over resource budget")
    #expect(transition.affectedMetrics == ["memory"])
  }

  @Test("High-detail sessions show limits, warn, end automatically, and never extend silently")
  func highDetailSessionLifecycle() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let pipeline = Pipeline(clock: clock, rules: [], observation: policy)
    let batch = (0..<10).flatMap { index -> [Sample] in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        Sample(timestamp: timestamp, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: timestamp, availability: .available, value: 0.5, metric: "memory"),
      ]
    }
    pipeline.requestHighDetail(duration: 120)
    let started = pipeline.evaluate(batch)
    #expect(started.observation?.mode == .highDetail(remaining: 60, limit: 60, warning: false))
    #expect(started.observation?.intervalsByMetric == ["cpu": 0.5, "memory": 0.5])
    #expect(started.observationTransitions.count == 1)
    let startTransition = try #require(started.observationTransitions.first)
    #expect(startTransition.from == .normal)
    #expect(startTransition.to == .highDetail)
    #expect(startTransition.reason == "high-detail session started")
    clock.advance(by: 10)
    pipeline.requestHighDetail(duration: 120)
    clock.advance(by: 45)
    let warning = pipeline.evaluate(batch)
    #expect(warning.observation?.mode == .highDetail(remaining: 5, limit: 60, warning: true))
    #expect(warning.observationTransitions.count == 1)
    let warningTransition = try #require(warning.observationTransitions.first)
    #expect(warningTransition.reason == "high-detail session ending soon")
    clock.advance(by: 10)
    let ended = pipeline.evaluate(batch)
    #expect(ended.observation?.mode == .normal)
    #expect(ended.observationTransitions.count == 1)
    let endTransition = try #require(ended.observationTransitions.first)
    #expect(endTransition.from == .highDetail)
    #expect(endTransition.to == .normal)
    #expect(endTransition.reason == "high-detail session ended")
  }

  @Test("High-detail sessions take precedence over budget pressure")
  func highDetailPrecedenceOverBudget() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let pipeline = Pipeline(clock: clock, rules: [], observation: policy)
    let batch = (0..<10).flatMap { index -> [Sample] in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        Sample(timestamp: timestamp, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: timestamp, availability: .available, value: 0.5, metric: "memory"),
      ]
    }
    let over = ResourceUsage(used: 2.0)
    pipeline.requestHighDetail(duration: 60)
    _ = pipeline.evaluate(batch)
    let held = pipeline.evaluate(batch, usage: over)
    #expect(held.observation?.mode == .highDetail(remaining: 60, limit: 60, warning: false))
    #expect(held.observationTransitions.isEmpty)
    clock.advance(by: 60)
    let expired = pipeline.evaluate(batch, usage: over)
    #expect(expired.observation?.mode == .normal)
    #expect(expired.observationTransitions.count == 1)
    let degraded = pipeline.evaluate(batch, usage: over)
    #expect(
      degraded.observation?.mode
        == .reduced(reason: "over resource budget", affectedMetrics: ["memory"])
    )
  }

  @Test("Aging detail compacts into summaries preserving required statistics")
  func agingDetailCompactsToSummaries() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = RetentionPolicy(
      detailRetention: 100,
      quota: 10_000,
      thresholdsByMetric: ["cpu": 0.5]
    )
    let pipeline = Pipeline(clock: clock, rules: [], retention: policy)
    let batch = (0..<10).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: index.isMultiple(of: 2) ? 0.25 : 0.75,
        metric: "cpu"
      )
    }
    _ = pipeline.evaluate(batch)
    clock.advance(by: 200)
    _ = pipeline.evaluate([])
    let history = try #require(pipeline.history)
    #expect(history.details.isEmpty)
    #expect(history.storageUnits == 0)
    #expect(history.summaries.count == 1)
    let summary = try #require(history.summaries.first)
    #expect(summary.metric == "cpu")
    #expect(summary.start == start)
    #expect(summary.end == start.addingTimeInterval(9))
    #expect(summary.count == 10)
    #expect(summary.min == 0.25)
    #expect(summary.max == 0.75)
    #expect(summary.average == 0.5)
    #expect(summary.variation == 0.25)
    #expect(summary.thresholdExceededDuration == 4.0)
    #expect(summary.incidentCount == 0)
  }

  @Test("Quota pressure summarizes oldest detail first while preserving metadata")
  func quotaPressureSummarizesOldestFirst() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = RetentionPolicy(
      detailRetention: 10_000,
      quota: 6,
      thresholdsByMetric: ["cpu": 0.5]
    )
    let pipeline = Pipeline(clock: clock, rules: [], retention: policy)
    let first = (0..<10).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.3,
        metric: "cpu"
      )
    }
    _ = pipeline.evaluate(first)
    let afterFirst = try #require(pipeline.history)
    #expect(afterFirst.details.count == 6)
    #expect(afterFirst.storageUnits == 6)
    #expect(afterFirst.summaries.count == 1)
    let oldest = try #require(afterFirst.summaries.first)
    #expect(oldest.start == start)
    #expect(oldest.end == start.addingTimeInterval(3))
    #expect(oldest.count == 4)
    #expect(oldest.average == 0.3)
    #expect(oldest.incidentCount == 0)
    let second = (10..<15).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.3,
        metric: "cpu"
      )
    }
    _ = pipeline.evaluate(second)
    let afterSecond = try #require(pipeline.history)
    #expect(afterSecond.details.count == 6)
    #expect(afterSecond.details.first?.timestamp == start.addingTimeInterval(9))
    #expect(afterSecond.summaries.count == 2)
    let newest = afterSecond.summaries.last
    #expect(newest?.start == start.addingTimeInterval(4))
    #expect(newest?.end == start.addingTimeInterval(8))
    #expect(newest?.count == 5)
  }

  @Test("Critical incident spans survive compaction")
  func criticalIncidentSpansSurviveCompaction() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = RetentionPolicy(
      detailRetention: 100,
      quota: 10_000,
      thresholdsByMetric: ["cpu": 0.8, "memory": 0.8]
    )
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule], retention: policy)
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let memory = (0..<22).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: 0.5,
        metric: "memory"
      )
    }
    let evaluation = pipeline.evaluate(cpu + memory)
    #expect(evaluation.incidents.count == 1)
    clock.advance(by: 200)
    _ = pipeline.evaluate([])
    let history = try #require(pipeline.history)
    #expect(history.incidents.count == 1)
    #expect(history.details.count == 20)
    #expect(
      Set(history.details.map(\.timestamp))
        == Set((5..<15).map { start.addingTimeInterval(TimeInterval($0)) })
    )
    #expect(history.summaries.count == 4)
  }

  @Test("Pinned incident spans survive compaction")
  func pinnedIncidentSpansSurviveCompaction() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let baselineConfig = BaselineConfig(
      promotionSamples: 5,
      maturitySamples: 100,
      deviationThreshold: 3,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30,
      stalenessWindow: 3600,
      algorithmVersion: "1"
    )
    let retentionPolicy = RetentionPolicy(
      detailRetention: 100,
      quota: 10_000,
      thresholdsByMetric: [:]
    )
    let pipeline = Pipeline(clock: clock, rules: [], baseline: baselineConfig, retention: retentionPolicy)
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
    pipeline.pin(incident)
    clock.advance(by: 300)
    _ = pipeline.evaluate([])
    let history = try #require(pipeline.history)
    #expect(history.incidents.count == 1)
    #expect(history.pinned.count == 1)
    #expect(history.details.count == 10)
    #expect(
      history.details.allSatisfy {
        $0.timestamp >= shiftStart && $0.timestamp < shiftStart.addingTimeInterval(10)
      }
    )
  }

  @Test("Exported packages round-trip with integrity intact")
  func exportedPackagesRoundTrip() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let evaluation = pipeline.evaluate(cpu)
    let timeline = try #require(evaluation.timelines.first)
    let summary = SampleSummary(
      metric: "cpu",
      start: start,
      end: start.addingTimeInterval(21),
      count: 22,
      min: 0.3,
      max: 0.99,
      average: 0.4,
      variation: 0.2,
      thresholdExceededDuration: 10,
      incidentCount: 1
    )
    let archive = IncidentArchive()
    let package = try archive.export(
      timeline,
      summaries: [summary],
      redactProcessNames: false,
      now: start.addingTimeInterval(30)
    )
    #expect(package.schemaVersion == IncidentPackage.currentSchemaVersion)
    #expect(package.manifest.sampleCount == timeline.metricSamples.count)
    #expect(!package.checksum.isEmpty)
    let data = try package.encoded()
    let preview = try archive.preview(data)
    #expect(preview.manifest.id == package.manifest.id)
    #expect(preview.sampleCount == timeline.metricSamples.count)
    let opened = try archive.open(data)
    #expect(opened.package.incident == timeline.incident)
    #expect(opened.package.metricSamples == timeline.metricSamples)
    #expect(opened.package.gaps == timeline.gaps)
    #expect(opened.package.markers == timeline.markers)
    #expect(opened.package.relevantProcesses == timeline.relevantProcesses)
    #expect(opened.package.observationTransitions == timeline.observationTransitions)
    #expect(opened.package.summaries == [summary])
    #expect(opened.package.ruleVersion == "1")
    #expect(opened.migratedFrom == nil)
    #expect(opened.reanalyses.isEmpty)
  }

  @Test("Export redacts sensitive process names when requested")
  func exportRedactsProcessNames() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let alpha = Process(id: "a", parent: nil, name: "Alpha")
    let beta = Process(id: "b", parent: "d", name: "Beta")
    let delta = Process(id: "d", parent: nil, name: "Delta")
    var activity: [ProcessSample] = []
    for index in 5..<16 {
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      activity.append(ProcessSample(timestamp: timestamp, process: alpha, metric: "cpu", value: 0.5))
      activity.append(ProcessSample(timestamp: timestamp, process: beta, metric: "cpu", value: 0.25))
    }
    for index in 0..<5 {
      activity.append(
        ProcessSample(
          timestamp: start.addingTimeInterval(TimeInterval(index)),
          process: delta,
          metric: "cpu",
          value: 0.1
        )
      )
    }
    let evaluation = pipeline.evaluate(cpu, processes: activity)
    let timeline = try #require(evaluation.timelines.first)
    let archive = IncidentArchive()
    let package = try archive.export(
      timeline,
      summaries: [],
      redactProcessNames: true,
      now: start.addingTimeInterval(30)
    )
    #expect(package.processNamesRedacted)
    #expect(package.relevantProcesses.map(\.process.id) == ["a", "b", "d"])
    #expect(package.relevantProcesses.allSatisfy { $0.process.name == "redacted" })
    #expect(
      package.relevantProcesses.allSatisfy { relevance in
        relevance.reasons.allSatisfy { reason in
          !reason.contains("Alpha") && !reason.contains("Beta") && !reason.contains("Delta")
        }
      }
    )
    let reopened = try archive.open(try package.encoded())
    #expect(reopened.package.relevantProcesses == package.relevantProcesses)
    let plain = try archive.export(
      timeline,
      summaries: [],
      redactProcessNames: false,
      now: start.addingTimeInterval(30)
    )
    #expect(!plain.processNamesRedacted)
    #expect(plain.relevantProcesses.map(\.process.name).contains("Alpha"))
  }

  @Test("Import rejects tampered, future-versioned, and malformed packages")
  func importRejectsInvalidPackages() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let evaluation = pipeline.evaluate(cpu)
    let timeline = try #require(evaluation.timelines.first)
    let archive = IncidentArchive()
    let package = try archive.export(
      timeline,
      summaries: [],
      redactProcessNames: false,
      now: start.addingTimeInterval(30)
    )
    let data = try package.encoded()
    let tampered = Data(
      String(decoding: data, as: UTF8.self).replacingOccurrences(of: "0.99", with: "0.11").utf8
    )
    #expect(throws: ArchiveError.checksumMismatch) {
      try archive.preview(tampered)
    }
    let future = Data(
      String(decoding: data, as: UTF8.self)
        .replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":99").utf8
    )
    #expect(throws: ArchiveError.unsupportedSchemaVersion(99)) {
      try archive.preview(future)
    }
    #expect(throws: ArchiveError.malformed) {
      try archive.preview(Data("not a package".utf8))
    }
    #expect(throws: ArchiveError.malformed) {
      try archive.open(Data("not a package".utf8))
    }
  }

  @Test("Opening the same package twice reports a duplicate")
  func openingTwiceReportsDuplicate() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let evaluation = pipeline.evaluate(cpu)
    let timeline = try #require(evaluation.timelines.first)
    let archive = IncidentArchive()
    let package = try archive.export(
      timeline,
      summaries: [],
      redactProcessNames: false,
      now: start.addingTimeInterval(30)
    )
    let data = try package.encoded()
    let opened = try archive.open(data)
    #expect(archive.stored.count == 1)
    #expect(throws: ArchiveError.duplicate(opened.package.manifest.id)) {
      try archive.open(data)
    }
    #expect(archive.stored.count == 1)
  }

  @Test("Archives stay isolated and label re-analysis separately from the original")
  func archivesStayIsolated() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let retention = RetentionPolicy(detailRetention: 10_000, quota: 10_000, thresholdsByMetric: [:])
    let pipeline = Pipeline(clock: clock, rules: [rule], retention: retention)
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let evaluation = pipeline.evaluate(cpu)
    let timeline = try #require(evaluation.timelines.first)
    let historyBefore = try #require(pipeline.history)
    let archive = IncidentArchive()
    let package = try archive.export(
      timeline,
      summaries: [],
      redactProcessNames: false,
      now: start.addingTimeInterval(30)
    )
    let opened = try archive.open(try package.encoded())
    let fresh = Pipeline(clock: ControlledClock(startingAt: start), rules: [rule])
    let reanalysis = fresh.evaluate(opened.package.metricSamples)
    try archive.recordReanalysis(
      packageID: opened.package.manifest.id,
      incidents: reanalysis.incidents,
      algorithmVersion: "2",
      at: start.addingTimeInterval(100)
    )
    let stored = try #require(archive.archived(packageID: opened.package.manifest.id))
    #expect(stored.package == package)
    #expect(stored.reanalyses.count == 1)
    let entry = try #require(stored.reanalyses.first)
    #expect(entry.label == "re-analysis")
    #expect(entry.algorithmVersion == "2")
    #expect(entry.incidents == reanalysis.incidents)
    #expect(pipeline.history == historyBefore)
    #expect(throws: ArchiveError.unknownPackage("missing")) {
      try archive.recordReanalysis(
        packageID: "missing",
        incidents: [],
        algorithmVersion: "2",
        at: start
      )
    }
  }

  @Test("Legacy packages migrate on an internal copy")
  func legacyPackagesMigrate() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let evaluation = pipeline.evaluate(cpu)
    let timeline = try #require(evaluation.timelines.first)
    let legacyContent = LegacyPackageContent(
      schemaVersion: 0,
      manifest: PackageManifest(
        id: UUID().uuidString,
        exportedAt: start.addingTimeInterval(30),
        schemaVersion: 0,
        incidentStart: timeline.incident.startedAt,
        incidentEnd: timeline.incident.recoveredAt,
        sampleCount: timeline.metricSamples.count
      ),
      incident: timeline.incident,
      metricSamples: timeline.metricSamples,
      gaps: timeline.gaps,
      markers: timeline.markers,
      relevantProcesses: timeline.relevantProcesses,
      summaries: [],
      ruleVersion: timeline.ruleVersion,
      baselineVersion: timeline.baselineVersion
    )
    let legacy = try LegacyPackage(content: legacyContent)
    let data = try legacy.encoded()
    let archive = IncidentArchive()
    let preview = try archive.preview(data)
    #expect(preview.migratedFrom == 0)
    let opened = try archive.open(data)
    #expect(opened.migratedFrom == 0)
    #expect(opened.package.schemaVersion == IncidentPackage.currentSchemaVersion)
    #expect(opened.package.observationTransitions.isEmpty)
    #expect(!opened.package.processNamesRedacted)
    #expect(opened.package.incident == timeline.incident)
    #expect(opened.package.metricSamples == timeline.metricSamples)
    #expect(try archive.preview(data).migratedFrom == 0)
  }

  @Test("Dashboard stays simple at rest and discloses detail on demand")
  func dashboardDisclosesDetailOnDemand() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let evaluation = pipeline.evaluate(Array(cpu.prefix(13)))
    let summary = makeDashboard(evaluation)
    #expect(summary.headline == "1 active incident")
    #expect(summary.activeIncidentCount == 1)
    #expect(summary.totalIncidentCount == 1)
    #expect(summary.incidents.isEmpty)
    #expect(summary.systemHealth == .unknown)
    #expect(summary.monitoring.headline == "Monitoring normal")
    let detailed = makeDashboard(evaluation, detail: .detailed)
    #expect(detailed.incidents.count == 1)
    let entry = try #require(detailed.incidents.first)
    #expect(entry.isActive)
    #expect(entry.startedAt == start.addingTimeInterval(5))
    let quiet = makeDashboard(pipeline.evaluate(Array(cpu.prefix(4))))
    #expect(quiet.headline == "No active incidents")
    #expect(quiet.systemHealth == .unknown)
  }

  @Test("Monitoring status names quality without ever naming health")
  func monitoringStatusNamesQuality() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let pipeline = Pipeline(clock: clock, rules: [], observation: policy)
    let batch = (0..<10).flatMap { index -> [Sample] in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        Sample(timestamp: timestamp, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: timestamp, availability: .available, value: 0.5, metric: "memory"),
      ]
    }
    let over = ResourceUsage(used: 2.0)
    let normal = pipeline.evaluate(batch, usage: ResourceUsage(used: 0.5))
    #expect(normal.observation?.mode == .normal)
    _ = pipeline.evaluate(batch, usage: over)
    let degraded = pipeline.evaluate(batch, usage: over)
    let reduced = try #require(degraded.observation.map(makeMonitoringStatus))
    #expect(reduced.headline == "Reduced monitoring")
    #expect(reduced.detail?.contains("over resource budget") == true)
    #expect(reduced.detail?.contains("memory") == true)
    pipeline.requestHighDetail(duration: 60)
    let close = pipeline.evaluate(batch)
    let detailed = try #require(close.observation.map(makeMonitoringStatus))
    #expect(detailed.headline == "High-detail investigation")
    #expect(detailed.detail?.contains("60s limit") == true)
    clock.advance(by: 55)
    let warning = try #require(pipeline.evaluate(batch).observation.map(makeMonitoringStatus))
    #expect(warning.detail?.contains("ending soon") == true)
    for status in [reduced, detailed, warning] {
      #expect(!status.headline.lowercased().contains("health"))
      #expect(!(status.detail ?? "").lowercased().contains("health"))
    }
    #expect(makeDashboard(degraded).systemHealth == .unknown)
    #expect(makeDashboard(close).systemHealth == .unknown)
  }

  @Test("Process rows separate aggregates and honor expand, collapse, and search")
  func processRowsHonorExpandCollapseSearch() throws {
    let timestamp = Date(timeIntervalSince1970: 0)
    let alpha = Process(id: "a", parent: nil, name: "Alpha")
    let beta = Process(id: "b", parent: "a", name: "Beta")
    let gamma = Process(id: "c", parent: nil, name: "Gamma")
    let samples = [
      ProcessSample(timestamp: timestamp, process: alpha, metric: "cpu", value: 0.5),
      ProcessSample(timestamp: timestamp, process: alpha, metric: "cpu", value: 0.5),
      ProcessSample(timestamp: timestamp, process: beta, metric: "cpu", value: 0.25),
      ProcessSample(timestamp: timestamp, process: beta, metric: "cpu", value: 0.25),
      ProcessSample(timestamp: timestamp, process: gamma, metric: "cpu", value: 0.1),
    ]
    let collapsed = processRows(samples)
    #expect(collapsed.map(\.process.id) == ["a", "c"])
    let alphaRow = try #require(collapsed.first)
    #expect(alphaRow.individualTotal == 1.0)
    #expect(alphaRow.subtreeTotal == 1.5)
    #expect(alphaRow.hasChildren)
    #expect(!alphaRow.isExpanded)
    #expect(alphaRow.depth == 0)
    let expanded = processRows(samples, expanded: ["a"])
    #expect(expanded.map(\.process.id) == ["a", "b", "c"])
    let betaRow = try #require(expanded.first { $0.process.id == "b" })
    #expect(betaRow.depth == 1)
    #expect(betaRow.individualTotal == 0.5)
    #expect(betaRow.subtreeTotal == 0.5)
    #expect(betaRow.isExpanded == false)
    let searched = processRows(samples, query: "bet")
    #expect(searched.map(\.process.id) == ["a", "b"])
    #expect(searched.first?.matchesQuery == false)
    #expect(searched.last?.matchesQuery == true)
    #expect(processRows(samples, query: "zzz").isEmpty)
  }

  @Test("Timeline points share one axis with tooltips that never zero-fill")
  func timelinePointsShareOneAxis() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule], observation: policy)
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let memory = (0..<22).map { index in
      let missing = index == 8
      return Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: missing ? .unavailable : .available,
        value: missing ? nil : 0.5,
        metric: "memory"
      )
    }
    let over = ResourceUsage(used: 2.0)
    _ = pipeline.evaluate(cpu + memory, usage: over)
    clock.advance(by: 10)
    let evaluation = pipeline.evaluate(cpu + memory, usage: over)
    let timeline = try #require(evaluation.timelines.first)
    let points = makeTimelinePoints(timeline)
    #expect(points.count == 11)
    #expect(points.map(\.timestamp) == points.map(\.timestamp).sorted())
    let gapPoint = try #require(points.first { $0.timestamp == start.addingTimeInterval(8) })
    #expect(gapPoint.valuesByMetric == ["cpu": 0.95])
    #expect(gapPoint.hasUnavailableData)
    #expect(gapPoint.tooltip == "cpu 0.95 · data unavailable")
    let startPoint = try #require(points.first { $0.timestamp == start.addingTimeInterval(5) })
    #expect(startPoint.markerKinds == [.started])
    #expect(startPoint.tooltip.contains("incident started"))
    let transitionPoint = try #require(points.first { $0.timestamp == start.addingTimeInterval(10) })
    #expect(transitionPoint.valuesByMetric == ["cpu": 0.95, "memory": 0.5])
    #expect(transitionPoint.observationNotes == ["over resource budget"])
    #expect(transitionPoint.tooltip == "cpu 0.95 · memory 0.5 · over resource budget")
  }

  @Test("Cyclic process parents terminate in tree rows")
  func cyclicProcessParentsTerminateInRows() {
    let timestamp = Date(timeIntervalSince1970: 0)
    let first = Process(id: "x", parent: "y", name: "Ex")
    let second = Process(id: "y", parent: "x", name: "Why")
    let samples = [
      ProcessSample(timestamp: timestamp, process: first, metric: "cpu", value: 0.5),
      ProcessSample(timestamp: timestamp, process: second, metric: "cpu", value: 0.5),
    ]
    #expect(processRows(samples).isEmpty)
  }

  @Test("Termination requires confirmation and verifies identity")
  func terminationRequiresConfirmation() throws {
    let fake = FakeExecutor(tokens: [123: "token-1"])
    let control = ProcessControl(executor: fake)
    let target = ControlledProcess(pid: 123, identityToken: "token-1", name: "Helper")
    #expect(control.terminate(target, confirmations: 0) == .confirmationRequired(count: 1))
    #expect(fake.terminations.isEmpty)
    #expect(control.terminate(target, confirmations: 1) == .exited)
    #expect(fake.terminations.count == 1)
    #expect(fake.terminations.first?.pid == 123)
    #expect(fake.terminations.first?.forcefully == false)
    let stale = ControlledProcess(pid: 123, identityToken: "token-0", name: "Helper")
    #expect(control.terminate(stale, confirmations: 1) == .identityChanged)
    #expect(fake.terminations.count == 1)
  }

  final class FakeExecutor: ProcessExecutor {
    var tokens: [Int: String]
    var terminations: [(pid: Int, forcefully: Bool)] = []
    var failures: [Int: ProcessExecutorError] = [:]

    init(tokens: [Int: String] = [:]) {
      self.tokens = tokens
    }

    func identityToken(for pid: Int) -> String? {
      tokens[pid]
    }

    func terminate(pid: Int, forcefully: Bool) throws {
      terminations.append((pid: pid, forcefully: forcefully))
      if let failure = failures[pid] {
        throw failure
      }
    }
  }

  @Test("Force quit needs two confirmations and refuses reused identities")
  func forceQuitNeedsTwoConfirmations() {
    let fake = FakeExecutor(tokens: [123: "token-1"])
    let control = ProcessControl(executor: fake)
    let target = ControlledProcess(pid: 123, identityToken: "token-1", name: "Helper")
    #expect(control.forceQuit(target, confirmations: 0) == .confirmationRequired(count: 2))
    #expect(control.forceQuit(target, confirmations: 1) == .confirmationRequired(count: 2))
    #expect(fake.terminations.isEmpty)
    #expect(control.forceQuit(target, confirmations: 2) == .exited)
    #expect(fake.terminations.count == 1)
    #expect(fake.terminations.first?.forcefully == true)
    fake.tokens[123] = "token-2"
    #expect(control.forceQuit(target, confirmations: 2) == .identityChanged)
    #expect(fake.terminations.count == 1)
  }

  @Test("Control failures explain themselves accurately")
  func controlFailuresExplainThemselves() {
    let fake = FakeExecutor(tokens: [1: "t1", 2: "t2"])
    fake.failures = [1: .permissionDenied, 2: .systemProtected]
    let control = ProcessControl(executor: fake)
    let denied = control.terminate(ControlledProcess(pid: 1, identityToken: "t1", name: "A"), confirmations: 1)
    #expect(denied == .refused(.permissionDenied))
    if case .refused(let refusal) = denied {
      #expect(refusal.explanation == "Termination was refused: the request lacks permission for this process.")
    } else {
      Issue.record("expected refusal")
    }
    let blocked = control.terminate(ControlledProcess(pid: 2, identityToken: "t2", name: "B"), confirmations: 1)
    #expect(blocked == .refused(.systemProtected))
    if case .refused(let refusal) = blocked {
      #expect(refusal.explanation == "Termination was refused: the process is protected by the system.")
    } else {
      Issue.record("expected refusal")
    }
    let gone = control.terminate(ControlledProcess(pid: 99, identityToken: "t9", name: "C"), confirmations: 1)
    #expect(gone == .refused(.alreadyExited))
    if case .refused(let refusal) = gone {
      #expect(refusal.explanation == "No action taken: the process had already exited.")
    } else {
      Issue.record("expected refusal")
    }
    let reused = control.terminate(ControlledProcess(pid: 1, identityToken: "stale", name: "A"), confirmations: 1)
    #expect(reused == .identityChanged)
  }

  @Test("Explanations separate facts, correlations, hypotheses, uncertainty, and gaps")
  func explanationsSeparateEvidenceGrades() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let memory = (0..<22).map { index in
      let missing = index == 8
      return Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: missing ? .unavailable : .available,
        value: missing ? nil : 0.5,
        metric: "memory"
      )
    }
    let alpha = Process(id: "a", parent: nil, name: "Alpha")
    let beta = Process(id: "b", parent: "d", name: "Beta")
    let delta = Process(id: "d", parent: nil, name: "Delta")
    var activity: [ProcessSample] = []
    for index in 5..<16 {
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      activity.append(ProcessSample(timestamp: timestamp, process: alpha, metric: "cpu", value: 0.5))
      activity.append(ProcessSample(timestamp: timestamp, process: beta, metric: "cpu", value: 0.25))
    }
    for index in 0..<5 {
      activity.append(
        ProcessSample(
          timestamp: start.addingTimeInterval(TimeInterval(index)),
          process: delta,
          metric: "cpu",
          value: 0.1
        )
      )
    }
    let evaluation = pipeline.evaluate(cpu + memory, processes: activity)
    let timeline = try #require(evaluation.timelines.first)
    let explanation = makeExplanation(timeline)
    #expect(
      explanation.facts == [
        "Incident observed from 1970-01-01T00:00:05Z to 1970-01-01T00:00:15Z.",
        "cpu: 11 readings, min 0.3, max 0.99.",
        "memory: 10 readings, min 0.5, max 0.5.",
        "Alpha held the largest share (0.67) during the incident.",
      ]
    )
    #expect(
      explanation.correlations == [
        "Alpha was active during the incident.",
        "Beta was active during the incident.",
        "Delta was active during the incident.",
      ]
    )
    #expect(
      explanation.hypotheses == [
        "Possible cause (unproven): Alpha's resource use is related to this incident."
      ]
    )
    #expect(explanation.uncertainty == ["Evidence is incomplete: 1 sample is missing."])
    #expect(explanation.unavailable == ["sample missing at 1970-01-01T00:00:08Z."])
    let empty = makeExplanation(
      IncidentTimeline(
        incident: Incident(startedAt: start, peakAt: start, recoveredAt: start, source: .rule(version: "1")),
        metricSamples: [],
        gaps: [],
        markers: [],
        ruleVersion: "1",
        baselineVersion: nil,
        relevantProcesses: []
      )
    )
    #expect(empty.facts.contains("No readings recorded for this incident."))
    #expect(empty.hypotheses == ["No hypothesis can be formed from the available evidence."])
    #expect(empty.uncertainty.isEmpty)
    #expect(empty.unavailable.isEmpty)
  }

  @Test("Notifications inform once with severity, then report recovery")
  func notificationsInformOnce() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = NotificationPolicy(cooldown: 30, highSeverityAfter: 60)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 5
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    var notifier = Notifier(policy: policy)
    let partial = pipeline.evaluate(Array(cpu.prefix(13)))
    let first = notifier.update(partial, now: start.addingTimeInterval(100))
    #expect(first.count == 1)
    let started = try #require(first.first)
    #expect(started.kind == .anomalyStarted)
    #expect(started.severity == .high)
    #expect(started.incidentStartedAt == start.addingTimeInterval(5))
    #expect(notifier.update(partial, now: start.addingTimeInterval(101)).isEmpty)
    let full = pipeline.evaluate(cpu)
    let second = notifier.update(full, now: start.addingTimeInterval(101))
    #expect(second.count == 1)
    let recovered = try #require(second.first)
    #expect(recovered.kind == .anomalyRecovered)
    #expect(recovered.severity == nil)
    #expect(notifier.update(full, now: start.addingTimeInterval(102)).isEmpty)
  }

  @Test("Recurrence within cooldown stays silent and observation changes notify once")
  func recurrenceAndObservationTransitions() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = NotificationPolicy(cooldown: 30, highSeverityAfter: 60)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 5
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let batch = (0..<40).map { index in
      let critical = (5..<11).contains(index) || (20..<26).contains(index)
      return Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .available,
        value: critical ? 0.9 : 0.3
      )
    }
    var notifier = Notifier(policy: policy)
    let partial = pipeline.evaluate(Array(batch.prefix(27)))
    #expect(partial.incidents.count == 2)
    let first = notifier.update(partial, now: start.addingTimeInterval(30))
    #expect(first.count == 1)
    #expect(first.first?.kind == .anomalyRecovered)
    let full = pipeline.evaluate(batch)
    let second = notifier.update(full, now: start.addingTimeInterval(40))
    #expect(second.count == 1)
    #expect(second.first?.kind == .anomalyRecovered)
    #expect(second.first?.incidentStartedAt == start.addingTimeInterval(20))
    let observationPolicy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 2,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let observed = Pipeline(clock: clock, rules: [], observation: observationPolicy)
    let calm = (0..<10).flatMap { index -> [Sample] in
      let timestamp = start.addingTimeInterval(TimeInterval(index))
      return [
        Sample(timestamp: timestamp, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: timestamp, availability: .available, value: 0.5, metric: "memory"),
      ]
    }
    let over = ResourceUsage(used: 2.0)
    let under = ResourceUsage(used: 0.5)
    #expect(notifier.update(observed.evaluate(calm, usage: under), now: start).isEmpty)
    _ = notifier.update(observed.evaluate(calm, usage: over), now: start)
    let limited = notifier.update(observed.evaluate(calm, usage: over), now: start)
    #expect(limited.count == 1)
    #expect(limited.first?.kind == .observationLimited)
    #expect(limited.first?.detail?.contains("memory") == true)
    _ = notifier.update(observed.evaluate(calm, usage: under), now: start)
    let restored = notifier.update(observed.evaluate(calm, usage: under), now: start)
    #expect(restored.count == 1)
    #expect(restored.first?.kind == .observationRestored)
    #expect(notifier.update(observed.evaluate(calm, usage: under), now: start).isEmpty)
  }

  @Test("Host collectors produce timestamped samples with honest availability")
  func hostCollectorsSpeakTheSeam() {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let clock = ControlledClock(startingAt: start)
    var collector = HostCollector(clock: clock)
    let first = collector.collect(now: clock.now())
    #expect(Set(first.map(\.metric)) == ["cpu", "memory"])
    #expect(first.allSatisfy { $0.timestamp == start })
    let cpu = first.first { $0.metric == "cpu" }
    #expect(cpu?.availability == .unavailable)
    #expect(cpu?.value == nil)
    let memory = first.first { $0.metric == "memory" }
    if memory?.availability == .available, let value = memory?.value {
      #expect(value >= 0 && value <= 1)
    } else {
      #expect(memory?.availability == .unavailable)
    }
  }

  @Test("Host collectors measure real deltas on repeat collections")
  func hostCollectorsMeasureDeltas() throws {
    let start = Date(timeIntervalSince1970: 2_000_000)
    let clock = ControlledClock(startingAt: start)
    var collector = HostCollector(clock: clock)
    let moment = start.addingTimeInterval(60)
    _ = collector.collect(now: start)
    var second = collector.collect(now: moment)
    for _ in 0..<40 {
      if second.first(where: { $0.metric == "cpu" })?.availability == .available {
        break
      }
      Thread.sleep(forTimeInterval: 0.05)
      second = collector.collect(now: moment)
    }
    let cpu = try #require(second.first { $0.metric == "cpu" })
    #expect(cpu.availability == .available)
    let value = try #require(cpu.value)
    #expect(value >= 0 && value <= 1)
    #expect(cpu.timestamp == moment)
    #expect(collector.lastDuration == 0)
  }

  @Test("Process enumeration yields samples with reuse-safe identity")
  func processEnumerationYieldsIdentity() throws {
    let start = Date(timeIntervalSince1970: 3_000_000)
    let clock = ControlledClock(startingAt: start)
    var collector = ProcessCollector()
    #expect(collector.collect(now: start).isEmpty)
    Thread.sleep(forTimeInterval: 0.2)
    let moment = start.addingTimeInterval(0.2)
    let samples = collector.collect(now: moment)
    #expect(!samples.isEmpty)
    #expect(samples.allSatisfy { $0.metric == "cpu" && $0.timestamp == moment })
    for sample in samples {
      #expect(!sample.process.id.isEmpty)
      #expect(sample.value >= 0 && sample.value <= 1)
    }
    let identities = samples.compactMap { collector.identity(for: $0.process) }
    #expect(identities.count == samples.count)
    for identity in identities {
      #expect(identity.token.hasPrefix("\(identity.pid)-"))
      #expect(!identity.name.isEmpty)
    }
  }

  @Test("Process CPU shares divide deltas by elapsed capacity")
  func processCPUShareMath() {
    #expect(
      ProcessCollector.cpuShare(
        userDeltaNanos: 1_000_000_000,
        systemDeltaNanos: 1_000_000_000,
        elapsedNanos: 2.0,
        processorCount: 4
      ) == 0.25
    )
    #expect(
      ProcessCollector.cpuShare(
        userDeltaNanos: 1_000_000_000,
        systemDeltaNanos: 1_000_000_000,
        elapsedNanos: 0,
        processorCount: 4
      ) == nil
    )
    #expect(
      ProcessCollector.cpuShare(
        userDeltaNanos: 1_000_000_000,
        systemDeltaNanos: 1_000_000_000,
        elapsedNanos: 2.0,
        processorCount: 0
      ) == nil
    )
  }

  @Test("Collector identities bridge into safe process control")
  func collectorIdentitiesBridgeToControl() throws {
    var collector = ProcessCollector()
    let start = Date(timeIntervalSince1970: 4_000_000)
    _ = collector.collect(now: start)
    Thread.sleep(forTimeInterval: 0.2)
    let moment = start.addingTimeInterval(0.2)
    let samples = collector.collect(now: moment)
    let sample = try #require(samples.first)
    let identity = try #require(collector.identity(for: sample.process))
    let fake = FakeExecutor(tokens: [Int(identity.pid): identity.token])
    let control = ProcessControl(executor: fake)
    let target = ControlledProcess(
      pid: Int(identity.pid),
      identityToken: identity.token,
      name: identity.name
    )
    #expect(control.terminate(target, confirmations: 1) == .exited)
    #expect(fake.terminations.count == 1)
    #expect(fake.terminations.first?.pid == Int(identity.pid))
    #expect(fake.terminations.first?.forcefully == false)
  }

  @Test("The capability matrix declares per-architecture expectations")
  func capabilityMatrixDeclaresExpectations() {
    let arm = CapabilityMatrix.forArchitecture("arm64")
    #expect(arm.architecture == "arm64")
    #expect(arm.supports("cpu"))
    #expect(arm.supports("memory"))
    #expect(!arm.supports("quantum"))
    let intel = CapabilityMatrix.forArchitecture("x86_64")
    #expect(intel.supports("cpu"))
    #expect(intel.supports("memory"))
    let unknown = CapabilityMatrix.forArchitecture("riscv")
    #expect(!unknown.supports("cpu"))
    #expect(!unknown.supports("memory"))
    let current = CapabilityMatrix.current()
    #expect(!current.architecture.isEmpty)
    #expect(current.supports("cpu"))
  }

  @Test("Unavailable metrics stay unavailable across every surface")
  func unavailableStaysUnavailableEverywhere() throws {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let cpu = SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples
    let memory = (0..<22).map { index in
      Sample(
        timestamp: start.addingTimeInterval(TimeInterval(index)),
        availability: .unavailable,
        value: nil,
        metric: "memory"
      )
    }
    let evaluation = pipeline.evaluate(cpu + memory)
    #expect(evaluation.incidents.count == 1)
    #expect(evaluation.gaps.count == 22)
    let timeline = try #require(evaluation.timelines.first)
    #expect(timeline.gaps.count == 11)
    #expect(!timeline.metricSamples.contains { $0.metric == "memory" })
    let points = makeTimelinePoints(timeline)
    #expect(points.allSatisfy { !$0.tooltip.contains("memory") })
    #expect(points.allSatisfy { $0.tooltip.contains("data unavailable") })
    let archive = IncidentArchive()
    let package = try archive.export(
      timeline,
      summaries: [],
      redactProcessNames: false,
      now: start.addingTimeInterval(30)
    )
    #expect(package.gaps.count == 11)
    #expect(!package.metricSamples.contains { $0.metric == "memory" })
    let reopened = try archive.open(try package.encoded())
    #expect(reopened.package.gaps == package.gaps)
  }

  @Test("Benchmarks run workloads and judge them against given budgets")
  func benchmarksJudgeGivenBudgets() {
    let idle = BenchmarkWorkload(
      name: "idle",
      batches: [BenchmarkBatch(samples: [], processes: [], usage: nil)],
      repetitions: 2
    )
    let normal = BenchmarkWorkload(
      name: "normal",
      batches: [
        BenchmarkBatch(
          samples: SyntheticStream.scenario(.normal, startingAt: Date(timeIntervalSince1970: 0), spacing: 1.0).samples,
          processes: [],
          usage: nil
        )
      ],
      repetitions: 2
    )
    let report = Benchmark.run(
      workloads: [idle, normal],
      budgets: ["idle": BenchmarkBudget(maxMeanWallSeconds: 60, maxMeanCPUNanos: nil, maxBlocksOut: nil)],
      measure: { _ in Evaluation(incidents: [], gaps: [], timelines: []) }
    )
    #expect(report.results.count == 2)
    let idleResult = report.results[0]
    #expect(idleResult.workloadName == "idle")
    #expect(idleResult.evaluations == 2)
    #expect(idleResult.totalSamples == 0)
    #expect(idleResult.meanWallSeconds >= 0)
    #expect(idleResult.verdict == .pass)
    let normalResult = report.results[1]
    #expect(normalResult.evaluations == 2)
    #expect(normalResult.totalSamples == 20)
    #expect(normalResult.verdict == .unmeasured)
  }

  @Test("Budget verdicts compare each axis independently")
  func budgetVerdictsCompareAxes() {
    let observed = ObservedCost(
      meanWallSeconds: 0.5,
      maxWallSeconds: 0.9,
      meanCPUNanos: 100,
      maxCPUNanos: 200,
      residentGrowthBytes: 1024,
      blocksOut: 4
    )
    #expect(judge(observed, against: nil) == .unmeasured)
    #expect(
      judge(
        observed,
        against: BenchmarkBudget(
          maxMeanWallSeconds: 1,
          maxMeanCPUNanos: 1000,
          maxResidentGrowthBytes: 2048,
          maxBlocksOut: 8
        )
      ) == .pass
    )
    #expect(
      judge(
        observed,
        against: BenchmarkBudget(
          maxMeanWallSeconds: 0.1,
          maxMeanCPUNanos: 1000,
          maxResidentGrowthBytes: 2048,
          maxBlocksOut: 8
        )
      ) == .fail(reasons: ["mean wall 0.5s exceeds budget 0.1s"])
    )
    let failed = judge(
      observed,
      against: BenchmarkBudget(
        maxMeanWallSeconds: 0.1,
        maxMeanCPUNanos: 10,
        maxResidentGrowthBytes: 100,
        maxBlocksOut: 1
      )
    )
    if case .fail(let reasons) = failed {
      #expect(reasons.count == 4)
    } else {
      Issue.record("expected failure")
    }
  }

  @Test("Benchmarks run the real engine across all three levels")
  func benchmarksRunRealEngine() {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.8,
      triggerDuration: 5,
      recoveryDuration: 5,
      cooldown: 30
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let idle = BenchmarkWorkload(
      name: "idle",
      batches: [BenchmarkBatch(samples: [], processes: [], usage: nil)],
      repetitions: 2
    )
    let normal = BenchmarkWorkload(
      name: "normal",
      batches: [
        BenchmarkBatch(
          samples: SyntheticStream.scenario(.normal, startingAt: start, spacing: 1.0).samples,
          processes: [],
          usage: nil
        )
      ],
      repetitions: 2
    )
    let investigation = BenchmarkWorkload(
      name: "investigation",
      batches: [
        BenchmarkBatch(
          samples: SyntheticStream.scenario(.sustainedPressure, startingAt: start, spacing: 1.0).samples,
          processes: [],
          usage: nil
        )
      ],
      repetitions: 2
    )
    let generous = BenchmarkBudget(
      maxMeanWallSeconds: 60,
      maxMeanCPUNanos: 60_000_000_000,
      maxResidentGrowthBytes: 1_000_000_000,
      maxBlocksOut: 1_000_000
    )
    let report = Benchmark.run(
      workloads: [idle, normal, investigation],
      budgets: ["idle": generous, "normal": generous, "investigation": generous],
      measure: { batch in pipeline.evaluate(batch.samples, processes: batch.processes, usage: batch.usage) }
    )
    #expect(report.results.count == 3)
    #expect(report.results.allSatisfy { $0.verdict == .pass })
    #expect(report.results.allSatisfy { $0.evaluations == 2 })
    #expect(report.results.map(\.totalSamples) == [0, 20, 44])
    #expect(report.results.allSatisfy { $0.meanWallSeconds >= 0 })
    #expect(!Benchmark.energyMeasured)
  }

  @Test("Benchmarks observe degradation engaging under budget pressure")
  func benchmarksObserveDegradation() {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let policy = ObservationPolicy(
      budgetLimit: 1.0,
      criticalMetrics: ["cpu"],
      normalInterval: 1.0,
      reducedInterval: 5.0,
      highDetailInterval: 0.5,
      overBudgetEvaluationsToDegrade: 1,
      underBudgetEvaluationsToRecover: 2,
      maximumHighDetailDuration: 60,
      highDetailWarningBeforeEnd: 10
    )
    let pipeline = Pipeline(clock: clock, rules: [], observation: policy)
    let loaded = BenchmarkWorkload(
      name: "loaded",
      batches: [
        BenchmarkBatch(
          samples: SyntheticStream.scenario(.normal, startingAt: start, spacing: 1.0).samples,
          processes: [],
          usage: ResourceUsage(used: 2.0)
        )
      ],
      repetitions: 3
    )
    var seen: [Evaluation] = []
    let report = Benchmark.run(
      workloads: [loaded],
      budgets: [:],
      measure: { batch in
        let evaluation = pipeline.evaluate(
          batch.samples,
          processes: batch.processes,
          usage: batch.usage
        )
        seen.append(evaluation)
        return evaluation
      }
    )
    #expect(seen.count == 3)
    #expect(seen.last?.observation?.mode == .reduced(reason: "over resource budget", affectedMetrics: []))
    #expect(report.results.first?.verdict == .unmeasured)
  }

  @Test("Helper verdicts follow probe evidence, never assumption")
  func helperVerdictsFollowEvidence() {
    let start = Date(timeIntervalSince1970: 0)
    let complete = PrivilegeProbe.assess(
      systemSamples: [
        Sample(timestamp: start, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: start, availability: .available, value: 0.5, metric: "memory"),
      ],
      processSamples: [
        ProcessSample(
          timestamp: start,
          process: Process(id: "1", parent: nil, name: "launchd"),
          metric: "cpu",
          value: 0.1
        )
      ],
      taskPortsAvailable: false
    )
    #expect(!complete.helperNeeded)
    #expect(complete.assessments.count == 3)
    #expect(complete.assessments.allSatisfy { $0.collectibleUnprivileged })
    #expect(complete.rationale == "All MVP metrics collect without privileges; no helper ships.")
    #expect(complete.notes.count == 1)
    let gapped = PrivilegeProbe.assess(
      systemSamples: [
        Sample(timestamp: start, availability: .available, value: 0.3, metric: "cpu"),
        Sample(timestamp: start, availability: .unavailable, value: nil, metric: "memory"),
      ],
      processSamples: [],
      taskPortsAvailable: false
    )
    #expect(!gapped.helperNeeded)
    #expect(gapped.rationale.contains("re-run"))
    #expect(gapped.assessments.contains { !$0.collectibleUnprivileged })
  }

  @Test("Cross-process task ports are denied without privileges")
  func crossProcessTaskPortsDenied() {
    #expect(!PrivilegeProbe.crossProcessTaskPorts())
  }

  @Test("Live collectors feed a complete no-helper verdict")
  func liveCollectorsFeedVerdict() throws {
    let start = Date(timeIntervalSince1970: 5_000_000)
    let clock = ControlledClock(startingAt: start)
    var host = HostCollector(clock: clock)
    var processes = ProcessCollector()
    _ = host.collect(now: start)
    _ = processes.collect(now: start)
    var system: [Sample] = []
    var activity: [ProcessSample] = []
    for step in 0..<10 {
      Thread.sleep(forTimeInterval: 0.05)
      let moment = start.addingTimeInterval(TimeInterval(step + 1) * 0.05)
      system = host.collect(now: moment)
      activity = processes.collect(now: moment)
      if system.first(where: { $0.metric == "cpu" })?.availability == .available,
        !activity.isEmpty
      {
        break
      }
    }
    let verdict = PrivilegeProbe.assess(
      systemSamples: system,
      processSamples: activity,
      taskPortsAvailable: PrivilegeProbe.crossProcessTaskPorts()
    )
    #expect(verdict.assessments.count == 3)
    #expect(!verdict.helperNeeded)
    #expect(verdict.rationale.contains("no helper ships"))
    #expect(verdict.notes.count == 1)
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
