import Foundation
import Testing

@testable import MonitoringEngine

private struct LoginItemError: Error {}

/// Stand-in for SMAppService: records what the store asked for and can be
/// told to fail, so tests never touch the real login-item state.
private final class FakeLoginItems: LoginItemService {
  var enabled: Bool
  var setCalls: [Bool] = []
  var error: Error?

  init(enabled: Bool = false) {
    self.enabled = enabled
  }

  func isEnabled() -> Bool {
    enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    if let error {
      throw error
    }
    setCalls.append(enabled)
    self.enabled = enabled
  }
}

private func freshDefaults() -> UserDefaults {
  UserDefaults(suiteName: "settings-test-\(UUID().uuidString)")!
}

@Suite("Settings store")
struct SettingsTests {
  @Test("Fresh store matches the Ship-07 defaults")
  func freshStoreMatchesShip07Defaults() {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    #expect(store.settings == MonitorSettings.ship07Defaults)
    #expect(store.settings.samplingInterval == 1.0)
    #expect(store.settings.launchAtLogin == false)
  }

  @Test("Interval options are exactly the Ship-07 cadences")
  func intervalOptionsAreShip07Cadences() {
    #expect(MonitorSettings.intervalOptions == [0.5, 1.0, 5.0])
  }

  @Test("Launch state reconciles with the login-item service on load")
  func launchStateReconcilesWithService() {
    // The user may have flipped the switch in System Settings; the service
    // wins over whatever we persisted.
    let defaults = freshDefaults()
    let first = SettingsStore(userDefaults: defaults, loginItems: FakeLoginItems(enabled: true))
    #expect(first.settings.launchAtLogin == true)
    let reloaded = SettingsStore(userDefaults: defaults, loginItems: FakeLoginItems(enabled: false))
    #expect(reloaded.settings.launchAtLogin == false)
  }

  @Test("Toggling launch at login writes through to the service")
  func launchToggleWritesThrough() throws {
    let service = FakeLoginItems()
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: service)
    try store.setLaunchAtLogin(true)
    #expect(service.setCalls == [true])
    #expect(store.settings.launchAtLogin == true)
    try store.setLaunchAtLogin(false)
    #expect(service.setCalls == [true, false])
    #expect(store.settings.launchAtLogin == false)
  }

  @Test("A no-op launch toggle never touches the service")
  func noopLaunchToggleSkipsService() throws {
    let service = FakeLoginItems()
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: service)
    try store.setLaunchAtLogin(false)
    #expect(service.setCalls.isEmpty)
  }

  @Test("A failing login-item service leaves settings untouched")
  func failingServiceLeavesSettingsUntouched() {
    let service = FakeLoginItems()
    service.error = LoginItemError()
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: service)
    #expect(throws: LoginItemError.self) {
      try store.setLaunchAtLogin(true)
    }
    #expect(store.settings.launchAtLogin == false)
    #expect(service.enabled == false)
  }

  @Test("Sampling interval changes persist, notify, and reload")
  func intervalChangePersistsNotifiesReloads() {
    let defaults = freshDefaults()
    let store = SettingsStore(userDefaults: defaults, loginItems: FakeLoginItems())
    var seen: [MonitorSettings] = []
    store.addChangeHandler { seen.append($0) }
    store.setSamplingInterval(5.0)
    #expect(store.settings.samplingInterval == 5.0)
    #expect(seen.count == 1)
    #expect(seen.first?.samplingInterval == 5.0)
    let reloaded = SettingsStore(userDefaults: defaults, loginItems: FakeLoginItems())
    #expect(reloaded.settings.samplingInterval == 5.0)
  }

  @Test("Intervals outside the Ship-07 options are ignored silently")
  func unknownIntervalsIgnored() {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    var notifications = 0
    store.addChangeHandler { _ in notifications += 1 }
    store.setSamplingInterval(2.0)
    #expect(store.settings.samplingInterval == 1.0)
    #expect(notifications == 0)
  }

  @Test("Restore returns every value to the Ship-07 defaults")
  func restoreReturnsShip07Defaults() throws {
    let defaults = freshDefaults()
    let service = FakeLoginItems()
    let store = SettingsStore(userDefaults: defaults, loginItems: service)
    try store.setLaunchAtLogin(true)
    store.setSamplingInterval(5.0)
    #expect(store.settings != MonitorSettings.ship07Defaults)
    var notifications = 0
    store.addChangeHandler { _ in notifications += 1 }
    try store.restoreDefaults()
    #expect(store.settings == MonitorSettings.ship07Defaults)
    #expect(service.enabled == false)
    #expect(notifications == 1)
    let reloaded = SettingsStore(userDefaults: defaults, loginItems: FakeLoginItems())
    #expect(reloaded.settings == MonitorSettings.ship07Defaults)
  }

  @Test("Launch toggle notifies observers with the new settings")
  func launchToggleNotifies() throws {
    let store = SettingsStore(userDefaults: freshDefaults(), loginItems: FakeLoginItems())
    var seen: [MonitorSettings] = []
    store.addChangeHandler { seen.append($0) }
    try store.setLaunchAtLogin(true)
    #expect(seen.count == 1)
    #expect(seen.first?.launchAtLogin == true)
    #expect(seen.first?.samplingInterval == 1.0)
  }
}
