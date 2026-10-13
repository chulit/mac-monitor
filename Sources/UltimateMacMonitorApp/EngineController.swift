import Combine
import Foundation
import MonitoringEngine

/// Owns the engine and its collectors, publishing each evaluation.
/// Views stay thin: they render `makeDashboard` and friends over the
/// published evaluation and add no logic of their own.
@MainActor
final class EngineController: ObservableObject {
  @Published private(set) var evaluation: Evaluation?
  @Published private(set) var processes: [ProcessSample] = []
  @Published private(set) var cpuShare: Double?
  @Published private(set) var cpuHistory: [(date: Date, value: Double)] = []
  @Published private(set) var memoryHistory: [(date: Date, value: Double)] = []
  @Published private(set) var baselineStatuses: [String: Baseline.Status] = [:]
  @Published private(set) var storageUnits = 0
  @Published private(set) var storageQuota = 150_000_000
  @Published private(set) var notices: [Notice] = []

  private var pipeline: Pipeline<SystemClock>
  private var host: HostCollector<SystemClock>
  private var processCollector = ProcessCollector()
  private var notifier = Notifier(
    policy: NotificationPolicy(cooldown: 900, highSeverityAfter: 300)
  )
  private var timer: Timer?

  init() {
    let clock = SystemClock()
    // Full engine configuration per Ship-07 numeric decisions.
    let rule = TechnicalRule(
      threshold: 0.9,
      triggerDuration: 30,
      recoveryDuration: 30,
      cooldown: 900
    )
    pipeline = Pipeline(
      clock: clock,
      rules: [rule],
      baseline: BaselineConfig(
        promotionSamples: 100,
        maturitySamples: 1000,
        deviationThreshold: 3.0,
        triggerDuration: 30,
        recoveryDuration: 30,
        cooldown: 900,
        stalenessWindow: 3600,
        algorithmVersion: "1"
      ),
      observation: ObservationPolicy(
        budgetLimit: 0.02,
        criticalMetrics: ["cpu"],
        normalInterval: 1.0,
        reducedInterval: 5.0,
        highDetailInterval: 0.5,
        overBudgetEvaluationsToDegrade: 3,
        underBudgetEvaluationsToRecover: 3,
        maximumHighDetailDuration: 600,
        highDetailWarningBeforeEnd: 60
      ),
      retention: RetentionPolicy(
        detailRetention: 604_800,
        quota: 150_000_000,
        thresholdsByMetric: ["cpu": 0.9, "memory": 0.9]
      )
    )
    host = HostCollector(clock: clock)
  }

  func start(interval: TimeInterval = 1.0) {
    stop()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tick()
      }
    }
    tick()
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  private func tick() {
    let now = Date()
    let samples = host.collect(now: now)
    let activity = processCollector.collect(now: now)
    let usage = totalShare(
      processes: activity,
      pid: ProcessInfo.processInfo.processIdentifier
    ).map(ResourceUsage.init(used:))
    let evaluation = pipeline.evaluate(samples, processes: activity, usage: usage)
    self.evaluation = evaluation
    processes = activity
    cpuShare = samples.first { $0.metric == "cpu" && $0.availability == .available }?.value
    if let cpu = samples.first(where: { $0.metric == "cpu" && $0.availability == .available })?.value {
      cpuHistory.append((date: now, value: cpu))
      cpuHistory = Array(cpuHistory.suffix(120))
    }
    if let memory = samples.first(where: { $0.metric == "memory" && $0.availability == .available })?.value {
      memoryHistory.append((date: now, value: memory))
      memoryHistory = Array(memoryHistory.suffix(120))
    }
    baselineStatuses = pipeline.baselines.mapValues { $0.status }
    if let history = pipeline.history {
      storageUnits = history.storageUnits
      storageQuota = history.quota
    }
    notices = Array((notices + notifier.update(evaluation, now: now)).suffix(50))
  }
}
