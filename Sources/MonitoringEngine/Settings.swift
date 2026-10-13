import Foundation

/// User-facing settings for Ultimate Mac Monitor.
///
/// Numeric defaults come from the Ship-07 decisions
/// (`.scratch/ship-readiness/issues/07-fix-numeric-acceptance-decisions.md`).
/// This type is UI-free on purpose: the app target binds it to controls,
/// the tests drive it directly, and neither needs the other.
public struct MonitorSettings: Codable, Equatable, Sendable {
  public var launchAtLogin: Bool
  public var samplingInterval: TimeInterval

  public init(launchAtLogin: Bool, samplingInterval: TimeInterval) {
    self.launchAtLogin = launchAtLogin
    self.samplingInterval = samplingInterval
  }

  /// The decided Ship-07 numbers: normal cadence 1.0s, launch at login off.
  /// The login item stays off until the user explicitly enables it; settings
  /// never change system state on their own.
  public static let ship07Defaults = MonitorSettings(
    launchAtLogin: false,
    samplingInterval: 1.0
  )

  /// The Ship-07 sampling cadences: high-detail 0.5s, normal 1.0s, reduced 5.0s.
  public static let intervalOptions: [TimeInterval] = [0.5, 1.0, 5.0]

  public static func label(for interval: TimeInterval) -> String {
    switch interval {
    case 0.5: return "0.5s — High detail"
    case 1.0: return "1.0s — Normal"
    case 5.0: return "5.0s — Reduced"
    default: return "\(interval)s"
    }
  }
}

/// The real login-item state. Behind a protocol so the engine never imports
/// ServiceManagement and tests never touch the system.
public protocol LoginItemService {
  func isEnabled() -> Bool
  func setEnabled(_ enabled: Bool) throws
}

/// Owns the persisted settings and applies them.
///
/// Threading: use from the main thread. UserDefaults and the login-item
/// service are main-thread APIs, and the change handlers feed UI and the
/// collection timer directly.
public final class SettingsStore {
  private let userDefaults: UserDefaults
  private let loginItems: LoginItemService
  private var changeHandlers: [(MonitorSettings) -> Void] = []
  private let storageKey = "com.ultimatemacmonitor.settings"

  public private(set) var settings: MonitorSettings

  public init(userDefaults: UserDefaults = .standard, loginItems: LoginItemService) {
    self.userDefaults = userDefaults
    self.loginItems = loginItems
    var loaded = MonitorSettings.ship07Defaults
    if let data = userDefaults.data(forKey: storageKey),
      let decoded = try? JSONDecoder().decode(MonitorSettings.self, from: data)
    {
      loaded = decoded
    }
    // The login-item service is the source of truth for launch state: the
    // user may have changed it in System Settings while we were away.
    loaded.launchAtLogin = loginItems.isEnabled()
    self.settings = loaded
    persist()
  }

  /// Called with the new settings after every successful mutation.
  public func addChangeHandler(_ handler: @escaping (MonitorSettings) -> Void) {
    changeHandlers.append(handler)
  }

  /// Toggles the real login item. Throws before any state changes, so a
  /// failing service leaves the stored settings untouched.
  public func setLaunchAtLogin(_ enabled: Bool) throws {
    guard enabled != settings.launchAtLogin else { return }
    try loginItems.setEnabled(enabled)
    update(MonitorSettings(launchAtLogin: enabled, samplingInterval: settings.samplingInterval))
  }

  /// Only the Ship-07 cadences are accepted; anything else is ignored so a
  /// corrupt stored value can never start a nonsense timer.
  public func setSamplingInterval(_ interval: TimeInterval) {
    guard interval != settings.samplingInterval else { return }
    guard MonitorSettings.intervalOptions.contains(interval) else { return }
    update(MonitorSettings(launchAtLogin: settings.launchAtLogin, samplingInterval: interval))
  }

  /// Returns every value to the decided Ship-07 numbers.
  public func restoreDefaults() throws {
    let defaults = MonitorSettings.ship07Defaults
    if defaults.launchAtLogin != settings.launchAtLogin {
      try loginItems.setEnabled(defaults.launchAtLogin)
    }
    update(defaults)
  }

  private func update(_ new: MonitorSettings) {
    settings = new
    persist()
    let current = settings
    for handler in changeHandlers {
      handler(current)
    }
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(settings) {
      userDefaults.set(data, forKey: storageKey)
    }
  }
}
