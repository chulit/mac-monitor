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
