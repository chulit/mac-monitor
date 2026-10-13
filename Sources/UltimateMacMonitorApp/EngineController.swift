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
  @Published private(set) var diskHistory: [(date: Date, value: Double)] = []
  @Published private(set) var networkHistory: [(date: Date, value: Double)] = []
  @Published private(set) var temperatureHistory: [(date: Date, value: Double)] = []
  @Published private(set) var temperatureSecondaryHistory: [(date: Date, value: Double)] = []
  @Published private(set) var temperatureStorageHistory: [(date: Date, value: Double)] = []
  @Published private(set) var temperatureFresh = false
  @Published private(set) var baselineStatuses: [String: Baseline.Status] = [:]
  @Published private(set) var storageUnits = 0
  @Published private(set) var storageQuota = 150_000_000
  @Published private(set) var notices: [Notice] = []

  private var pipeline: Pipeline<SystemClock>
  private var host: HostCollector<SystemClock>
  private var processCollector = ProcessCollector()
  private var networkCollector = NetworkCollector()
  private var temperatureCollector = TemperatureCollector()
  private var notifier = Notifier(
    policy: NotificationPolicy(cooldown: 900, highSeverityAfter: 300)
  )
  private var timer: Timer?

  init() {
    let clock = SystemClock()
    // Full engine configuration per Ship-07 numeric decisions. Rules stay
    // scoped to fraction metrics: unbounded series (network) and physical
    // units (temperature) would otherwise trip absolute thresholds.
    let rule = TechnicalRule(
      threshold: 0.9,
      triggerDuration: 30,
      recoveryDuration: 30,
      cooldown: 900,
      metrics: ["cpu", "memory", "disk"]
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

  func requestHighDetail(seconds: TimeInterval) {
    pipeline.requestHighDetail(duration: seconds)
  }

  private func tick() {
    let now = Date()
    let activity = processCollector.collect(now: now)
    var samples =
      host.collect(now: now) + networkCollector.collect(now: now)
      + temperatureCollector.collect(now: now)
    if let systemCPU = processCollector.systemCPUSample() {
      samples.insert(systemCPU, at: 0)
    }
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
    if let disk = samples.first(where: { $0.metric == "disk" && $0.availability == .available })?.value {
      diskHistory.append((date: now, value: disk))
      diskHistory = Array(diskHistory.suffix(120))
    }
    if let network = samples.first(where: { $0.metric == "network" && $0.availability == .available })?.value {
      networkHistory.append((date: now, value: network))
      networkHistory = Array(networkHistory.suffix(120))
    }
    if let temperature = samples.first(where: { $0.metric == "temperature" && $0.availability == .available })?.value {
      temperatureHistory.append((date: now, value: temperature))
      temperatureHistory = Array(temperatureHistory.suffix(120))
    }
    // A reading older than five ticks is displayed as unavailable, never
    // as a stale value masquerading as current.
    temperatureFresh =
      temperatureHistory.last.map { now.timeIntervalSince($0.date) <= 5 } ?? false
    if let secondary = samples.first(where: { $0.metric == "temperature.secondary" && $0.availability == .available })?.value {
      temperatureSecondaryHistory.append((date: now, value: secondary))
      temperatureSecondaryHistory = Array(temperatureSecondaryHistory.suffix(120))
    }
    if let storage = samples.first(where: { $0.metric == "temperature.storage" && $0.availability == .available })?.value {
      temperatureStorageHistory.append((date: now, value: storage))
      temperatureStorageHistory = Array(temperatureStorageHistory.suffix(120))
    }
    baselineStatuses = pipeline.baselines.mapValues { $0.status }
    if let history = pipeline.history {
      storageUnits = history.storageUnits
      storageQuota = history.quota
    }
    notices = Array((notices + notifier.update(evaluation, now: now)).suffix(50))
  }
}
