import Foundation
import Testing

@testable import MonitoringEngine

private final class FakeLoginItems: LoginItemService {
  var enabled = false
  func isEnabled() -> Bool { enabled }
  func setEnabled(_ enabled: Bool) throws { self.enabled = enabled }
}

private func freshDefaults() -> UserDefaults {
  UserDefaults(suiteName: "settings-center-test-\(UUID().uuidString)")!
}

private func stream(value: Double, count: Int, from start: Date, metric: String = "cpu") -> [Sample] {
  (0..<count).map { i in
    Sample(
      timestamp: start.addingTimeInterval(Double(i)),
      availability: .available,
      value: value,
      metric: metric
    )
  }
}

@Suite("Settings center")
struct SettingsCenterTests {
  @Test("Fresh store carries the new defaults")
  func newDefaults() {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    let s = store.settings
    #expect(s.monitoringMode == .normal)
    #expect(s.thresholdCPU == 0.85)
    #expect(s.thresholdMemory == 0.85)
    #expect(s.thresholdDisk == 0.90)
    #expect(s.retentionDays == 30)
    #expect(s.theme == .auto)
    #expect(s.accentColor == "blue")
    #expect(s.density == .default)
    #expect(s.showSidebarLabels == true)
    #expect(s.compactSidebar == false)
    #expect(s.reduceMotion == false)
    #expect(s.notificationsEnabled == true)
    #expect(s.storeMetrics == true)
    #expect(s.hideSensitiveInfo == false)
    #expect(s.metricIntervals["cpu"] == 1)
    #expect(s.isMonitored("cpu") == true)
    #expect(s.isAlertTypeEnabled(AlertType.highCPU.rawValue) == true)
  }

  @Test("Generic update persists and notifies")
  func genericUpdate() {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    var seen: [MonitorSettings] = []
    store.addChangeHandler { seen.append($0) }
    store.update(\.theme, to: .dark)
    #expect(store.settings.theme == .dark)
    #expect(seen.count == 1)
    #expect(seen.first?.theme == .dark)
    // No-op writes stay silent.
    store.update(\.theme, to: .dark)
    #expect(seen.count == 1)
  }

  @Test("Monitoring mode drives the sampling interval")
  func monitoringMode() {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    store.setMonitoringMode(.reduced)
    #expect(store.settings.monitoringMode == .reduced)
    #expect(store.settings.samplingInterval == 5.0)
    store.setMonitoringMode(.highDetail)
    #expect(store.settings.samplingInterval == 0.5)
  }

  @Test("Settings persisted by older versions still decode")
  func legacyJSONDecodes() throws {
    let defaults = freshDefaults()
    let legacy = #"{"launchAtLogin":false,"samplingInterval":1.0}"#.data(using: .utf8)!
    defaults.set(legacy, forKey: "com.ultimatemacmonitor.settings")
    let store = SettingsStore(userDefaults: defaults, loginItems: FakeLoginItems())
    #expect(store.settings.theme == .auto)
    #expect(store.settings.retentionDays == 30)
    #expect(store.settings.thresholdCPU == 0.85)
  }

  @Test("Restore defaults resets the new fields")
  func restoreDefaults() throws {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    store.update(\.theme, to: .dark)
    store.update(\.retentionDays, to: 90)
    store.update(\.thresholdCPU, to: 0.5)
    try store.restoreDefaults()
    #expect(store.settings == MonitorSettings.ship07Defaults)
  }

  @Test("metricIsDue gates on enablement and cadence")
  func metricDue() {
    let now = Date(timeIntervalSince1970: 1_000)
    #expect(metricIsDue(metric: "cpu", lastFire: nil, now: now, interval: 5, enabled: true) == true)
    #expect(metricIsDue(metric: "cpu", lastFire: nil, now: now, interval: 5, enabled: false) == false)
    #expect(metricIsDue(
      metric: "cpu", lastFire: now.addingTimeInterval(-3), now: now, interval: 5, enabled: true
    ) == false)
    #expect(metricIsDue(
      metric: "cpu", lastFire: now.addingTimeInterval(-5), now: now, interval: 5, enabled: true
    ) == true)
  }

  @Test("alertTypeID maps metrics to alert types")
  func alertTypeMapping() {
    #expect(alertTypeID(forMetric: "cpu") == AlertType.highCPU.rawValue)
    #expect(alertTypeID(forMetric: "memory") == AlertType.highMemory.rawValue)
    #expect(alertTypeID(forMetric: "network") == AlertType.networkActivity.rawValue)
    #expect(alertTypeID(forMetric: "temperature") == AlertType.highTemperature.rawValue)
    #expect(alertTypeID(forMetric: nil) == nil)
    #expect(alertTypeID(forMetric: "unknown-metric") == nil)
  }

  @Test("Updating rule thresholds changes detection live")
  func thresholdUpdate() {
    let start = Date(timeIntervalSince1970: 0)
    let clock = ControlledClock(startingAt: start)
    let rule = TechnicalRule(
      threshold: 0.95, triggerDuration: 5, recoveryDuration: 5, cooldown: 30,
      metrics: ["cpu"]
    )
    let pipeline = Pipeline(clock: clock, rules: [rule])
    let samples = stream(value: 0.9, count: 20, from: start)
    #expect(pipeline.evaluate(samples).incidents.isEmpty)
    pipeline.updateRuleThresholds(["cpu": 0.5])
    #expect(pipeline.evaluate(samples).incidents.count == 1)
  }

  @Test("Updating retention compacts older details")
  func retentionUpdate() {
    let now = Date(timeIntervalSince1970: 100_000)
    let clock = ControlledClock(startingAt: now)
    let pipeline = Pipeline(
      clock: clock,
      retention: RetentionPolicy(
        detailRetention: 2_592_000, quota: 1_000_000, thresholdsByMetric: [:]
      )
    )
    let old = stream(value: 0.2, count: 10, from: now.addingTimeInterval(-864_000))
    pipeline.evaluate(old)
    #expect(pipeline.history?.details.count == 10)
    pipeline.updateRetention(detailRetention: 3_600)
    pipeline.evaluate(stream(value: 0.2, count: 5, from: now))
    #expect(pipeline.history?.details.count == 5)
  }

  @Test("Clear history drops recorded data")
  func clearHistory() {
    let now = Date(timeIntervalSince1970: 100_000)
    let clock = ControlledClock(startingAt: now)
    let pipeline = Pipeline(
      clock: clock,
      retention: RetentionPolicy(
        detailRetention: 2_592_000, quota: 1_000_000, thresholdsByMetric: [:]
      )
    )
    pipeline.evaluate(stream(value: 0.2, count: 10, from: now))
    #expect(pipeline.history?.details.isEmpty == false)
    pipeline.clearHistory()
    #expect(pipeline.history?.details.isEmpty == true)
    #expect(pipeline.history?.incidents.isEmpty == true)
  }

  @Test("History recording flags gate what is stored")
  func historyRecordingFlags() {
    let now = Date(timeIntervalSince1970: 100_000)
    let clock = ControlledClock(startingAt: now)
    let pipeline = Pipeline(
      clock: clock,
      retention: RetentionPolicy(
        detailRetention: 2_592_000, quota: 1_000_000, thresholdsByMetric: [:]
      )
    )
    pipeline.setHistoryRecording([])
    pipeline.evaluate(stream(value: 0.2, count: 10, from: now))
    #expect(pipeline.history?.details.isEmpty == true)
    pipeline.setHistoryRecording(.metricsAndIncidents)
    pipeline.evaluate(stream(value: 0.2, count: 10, from: now.addingTimeInterval(20)))
    #expect(pipeline.history?.details.isEmpty == false)
  }
}
