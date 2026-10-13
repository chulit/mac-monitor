import AppKit
import Combine
import Foundation
import MonitoringEngine
import UserNotifications

/// Appearance-related settings mirrored out of the store so SwiftUI views
/// can react to them. The store stays UI-free; this is the reactive bridge.
struct AppearanceSnapshot: Equatable {
  var theme: AppTheme
  var accentColor: AccentColorName
  var density: InterfaceDensity
  var showSidebarLabels: Bool
  var compactSidebar: Bool
  var reduceMotion: Bool

  init(settings: MonitorSettings) {
    self.theme = settings.theme
    self.accentColor = settings.accentColor
    self.density = settings.density
    self.showSidebarLabels = settings.showSidebarLabels
    self.compactSidebar = settings.compactSidebar
    self.reduceMotion = settings.reduceMotion
  }
}

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
  @Published private(set) var baselineMeans: [String: Double] = [:]
  @Published private(set) var storageUnits = 0
  @Published private(set) var storageQuota = 150_000_000
  @Published private(set) var notices: [Notice] = []
  /// Mirrored appearance settings so views react without observing the store.
  @Published private(set) var appearance = AppearanceSnapshot(settings: .ship07Defaults)

  private var pipeline: Pipeline<SystemClock>
  private var host: HostCollector<SystemClock>
  private var processCollector = ProcessCollector()
  private var networkCollector = NetworkCollector()
  private var temperatureCollector = TemperatureCollector()
  private var notifier = Notifier(
    policy: NotificationPolicy(cooldown: 900, highSeverityAfter: 300)
  )
  private var timer: Timer?
  private var tickCount = 0
  /// Last collection time per metric for the per-metric cadence settings.
  private var lastMetricFire: [String: Date] = [:]

  /// The user-facing settings. Owns the store when the caller passes none so
  /// the controller always has a real login-item service behind it.
  let settings: SettingsStore
  /// Release checker backing the About panel and the auto-update setting.
  let updater = UpdateChecker()
  private var collectionInterval: TimeInterval

  init(settings: SettingsStore? = nil) {
    let store = settings ?? SettingsStore(loginItems: SMAppServiceLoginItems())
    self.settings = store
    self.collectionInterval = store.settings.samplingInterval
    let clock = SystemClock()
    // One rule per fraction metric so alert thresholds stay independent:
    // each metric gets its own excursion tracking and its own threshold
    // from Settings. Rules stay scoped to fraction metrics: unbounded
    // series (network) and physical units (temperature) would otherwise
    // trip absolute thresholds.
    let rules = ["cpu", "memory", "disk"].map { metric in
      TechnicalRule(
        threshold: store.settings.threshold(for: metric),
        triggerDuration: 30,
        recoveryDuration: 30,
        cooldown: 900,
        metrics: [metric]
      )
    }
    pipeline = Pipeline(
      clock: clock,
      rules: rules,
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
        maximumHighDetailDuration: 1800,
        highDetailWarningBeforeEnd: 60
      ),
      retention: RetentionPolicy(
        detailRetention: Double(store.settings.retentionDays) * 86_400,
        quota: 150_000_000,
        thresholdsByMetric: ["cpu": 0.9, "memory": 0.9]
      )
    )
    pipeline.setHistoryRecording(historyRecording(for: store.settings))
    pipeline.updateBudgetLimit(store.settings.maxCPU)
    pipeline.updateCriticalMetrics(criticalMetrics(for: store.settings))
    AppLog.isEnabled = store.settings.storeLogs
    appearance = AppearanceSnapshot(settings: store.settings)
    host = HostCollector(clock: clock)
    store.addChangeHandler { [weak self] newSettings in
      Task { @MainActor in
        self?.applySettings(newSettings)
      }
    }
  }

  private func historyRecording(for settings: MonitorSettings) -> Pipeline<SystemClock>.HistoryRecording {
    var recording: Pipeline<SystemClock>.HistoryRecording = []
    if settings.storeMetrics {
      recording.insert(.metrics)
    }
    if settings.storeIncidents {
      recording.insert(.incidents)
    }
    return recording
  }

  /// Metrics exempt from observation degradation: only monitored ones.
  private func criticalMetrics(for settings: MonitorSettings) -> Set<String> {
    settings.isMonitored("cpu") ? ["cpu"] : []
  }

  /// Starts collection at the cadence chosen in settings.
  func start() {
    start(interval: settings.settings.samplingInterval)
    if settings.settings.checkForUpdates {
      Task {
        await updater.check()
      }
    }
  }

  func start(interval: TimeInterval) {
    collectionInterval = interval
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

  /// Identity token binding a process to its start time, for the safe
  /// termination flow: a reused PID never matches a stale token.
  func processIdentity(for process: Process) -> ProcessIdentity? {
    processCollector.identity(for: process)
  }

  /// Ends the high-detail session early (Stop Investigation button).
  func endHighDetail() {
    pipeline.endHighDetail()
  }

  /// Incidents that have not recovered: the sidebar badge and the popover
  /// incident card read this instead of filtering the evaluation themselves.
  var activeIncidents: [Incident] {
    evaluation?.incidents.filter { $0.recoveredAt == nil } ?? []
  }

  /// Recorded history (detail samples, compact summaries, incidents) for the
  /// History screen. Read on demand so the per-tick publish cycle stays lean.
  func historySnapshot() -> HistorySnapshot? {
    pipeline.history
  }

  var activeIncidentCount: Int {
    activeIncidents.count
  }

  /// Whether a high-detail investigation session is running. Cards show their
  /// baseline delta badges only in this mode.
  var isInvestigating: Bool {
    if case .highDetail = evaluation?.observation?.mode {
      return true
    }
    return false
  }

  /// Restarts collection when the settings window picks a new cadence.
  /// Anything else (launch at login, restore of an unchanged interval) leaves
  /// the running timer alone.
  private func applySettings(_ newSettings: MonitorSettings) {
    if newSettings.samplingInterval != collectionInterval {
      start(interval: newSettings.samplingInterval)
    }
    pipeline.updateRuleThresholds([
      "cpu": newSettings.thresholdCPU,
      "memory": newSettings.thresholdMemory,
      "disk": newSettings.thresholdDisk,
    ])
    pipeline.updateRetention(detailRetention: Double(newSettings.retentionDays) * 86_400)
    pipeline.setHistoryRecording(historyRecording(for: newSettings))
    pipeline.updateBudgetLimit(newSettings.maxCPU)
    pipeline.updateCriticalMetrics(criticalMetrics(for: newSettings))
    AppLog.isEnabled = newSettings.storeLogs
    appearance = AppearanceSnapshot(settings: newSettings)
    updateDockBadge()
  }

  private func tick() {
    tickCount += 1
    if tickCount % 60 == 1 {
      AppLog.event("tick #\(tickCount)")
    }
    let now = Date()
    let activity = processCollector.collect(now: now)
    var samples = collectDueSamples(now: now)
    let usage = totalShare(
      processes: activity,
      pid: ProcessInfo.processInfo.processIdentifier
    ).map(ResourceUsage.init(used:))
    let evaluation = pipeline.evaluate(samples, processes: activity, usage: usage)
    self.evaluation = evaluation
    processes = activity
    cpuShare = samples.first { $0.metric == "cpu" && $0.availability == .available }?.value
    // The rolling chart buffers are the "cache": disabling it stops them filling.
    if settings.settings.enableCache {
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
    }
    // A reading older than five ticks is displayed as unavailable, never
    // as a stale value masquerading as current.
    temperatureFresh =
      temperatureHistory.last.map { now.timeIntervalSince($0.date) <= 5 } ?? false
    if settings.settings.enableCache {
      if let secondary = samples.first(where: { $0.metric == "temperature.secondary" && $0.availability == .available })?.value {
        temperatureSecondaryHistory.append((date: now, value: secondary))
        temperatureSecondaryHistory = Array(temperatureSecondaryHistory.suffix(120))
      }
      if let storage = samples.first(where: { $0.metric == "temperature.storage" && $0.availability == .available })?.value {
        temperatureStorageHistory.append((date: now, value: storage))
        temperatureStorageHistory = Array(temperatureStorageHistory.suffix(120))
      }
    }
    baselineStatuses = pipeline.baselines.mapValues { $0.status }
    baselineMeans = pipeline.baselines.compactMapValues { $0.isActive ? $0.mean : nil }
    if let history = pipeline.history {
      storageUnits = history.storageUnits
      storageQuota = history.quota
    }
    notices = Array((notices + freshNotices(from: evaluation, now: now)).suffix(50))
  }

  /// Collects only the metrics that are enabled and due per the
  /// per-metric cadence settings. Process activity always collects: the
  /// process table needs every tick.
  private func collectDueSamples(now: Date) -> [Sample] {
    let stored = settings.settings
    var samples: [Sample] = []
    func due(_ metric: String) -> Bool {
      metricIsDue(
        lastFire: lastMetricFire[metric],
        now: now,
        interval: stored.metricIntervals[metric] ?? 1,
        enabled: stored.isMonitored(metric)
      )
    }
    func markFired(_ metrics: [String]) {
      for metric in metrics {
        lastMetricFire[metric] = now
      }
    }
    if due("cpu"), let systemCPU = processCollector.systemCPUSample() {
      samples.append(systemCPU)
      markFired(["cpu"])
    }
    let hostMetrics = ["memory", "disk"].filter(due)
    if !hostMetrics.isEmpty {
      let produced = host.collect(now: now).filter { hostMetrics.contains($0.metric) }
      samples += produced
      markFired(hostMetrics)
    }
    if due("network") {
      samples += networkCollector.collect(now: now)
      markFired(["network"])
    }
    if due("temperature") {
      samples += temperatureCollector.collect(now: now)
      markFired(["temperature"])
    }
    return samples
  }

  /// Generates notices through the notifier (keeping its dedupe state warm)
  /// but only surfaces and delivers them when notifications are enabled and
  /// the notice's alert type is on.
  private func freshNotices(from evaluation: Evaluation, now: Date) -> [Notice] {
    let fresh = notifier.update(evaluation, now: now)
    let stored = settings.settings
    guard stored.notificationsEnabled else {
      // The badge must clear even when nothing is delivered.
      updateDockBadge()
      return []
    }
    let deliverable = fresh.filter { notice in
      guard let metric = metricForNotice(notice, in: evaluation) else {
        return true
      }
      guard let type = alertTypeID(forMetric: metric) else {
        return true
      }
      return stored.isAlertTypeEnabled(type)
    }
    deliver(deliverable)
    return deliverable
  }

  private func metricForNotice(_ notice: Notice, in evaluation: Evaluation) -> String? {
    guard let startedAt = notice.incidentStartedAt,
      let incident = evaluation.incidents.first(where: { $0.startedAt == startedAt }),
      let timeline = evaluation.timelines.first(where: { $0.incident == incident })
    else {
      return nil
    }
    return timeline.metricSamples.first?.metric
  }

  private func deliver(_ notices: [Notice]) {
    let stored = settings.settings
    if stored.macOSNotifications {
      requestNotificationAuthorizationIfNeeded()
      for notice in notices {
        postMacOSNotification(notice)
      }
    }
    // Sound is for critical alerts only: high-severity notices.
    if stored.alertSound, notices.contains(where: { $0.severity == .high }) {
      NSSound(named: "Glass")?.play()
    }
    updateDockBadge()
  }

  private var didRequestNotificationAuthorization = false

  private func requestNotificationAuthorizationIfNeeded() {
    guard !didRequestNotificationAuthorization else {
      return
    }
    didRequestNotificationAuthorization = true
    UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound]) { _, _ in }
  }

  private func postMacOSNotification(_ notice: Notice) {
    let content = UNMutableNotificationContent()
    content.title = "Ultimate Mac Monitor"
    content.body = notice.message
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func updateDockBadge() {
    guard settings.settings.notificationsEnabled, settings.settings.dockBadge else {
      NSApplication.shared.dockTile.badgeLabel = nil
      return
    }
    let count = activeIncidentCount
    NSApplication.shared.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
  }

  /// Whether the collection timer is running (Settings → Permissions).
  var isCollecting: Bool {
    timer != nil
  }

  /// Privacy setting shortcut: hides process names and file paths in
  /// exports and screenshots.
  var hidesSensitiveInfo: Bool {
    settings.settings.hideSensitiveInfo
  }

  /// Drops all recorded history (Settings → Clear History).
  func clearHistory() {
    pipeline.clearHistory()
    storageUnits = 0
  }

  /// Drops the in-memory rolling chart buffers (Settings → Clear Cache).
  func clearCache() {
    cpuHistory = []
    memoryHistory = []
    diskHistory = []
    networkHistory = []
    temperatureHistory = []
    temperatureSecondaryHistory = []
    temperatureStorageHistory = []
  }
}
