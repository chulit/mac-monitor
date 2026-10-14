import Foundation

/// Monitoring mode: the user-facing names for the Ship-07 cadences.
public enum MonitoringMode: String, Codable, Sendable, CaseIterable {
  case normal
  case reduced
  case highDetail

  public var samplingInterval: TimeInterval {
    switch self {
    case .normal: return 1.0
    case .reduced: return 5.0
    case .highDetail: return 0.5
    }
  }

  public var title: String {
    switch self {
    case .normal: return "Normal"
    case .reduced: return "Reduced"
    case .highDetail: return "High Detail"
    }
  }

  public var subtitle: String {
    switch self {
    case .normal: return "Balanced for everyday use"
    case .reduced: return "Lower overhead"
    case .highDetail: return "More data for investigation"
    }
  }
}

public enum AppTheme: String, Codable, Sendable, CaseIterable {
  case light
  case dark
  case auto

  public var title: String {
    switch self {
    case .light: return "Light"
    case .dark: return "Dark"
    case .auto: return "Auto"
    }
  }
}

/// Accent color choices. Raw values match the previously stored strings,
/// so settings persisted before this type existed still decode.
public enum AccentColorName: String, Codable, Sendable, CaseIterable {
  case blue
  case purple
  case pink
  case orange
  case yellow
  case green
  case cyan
  case multicolor
}

public enum InterfaceDensity: String, Codable, Sendable, CaseIterable {  case `default`
  case compact
  case spacious

  public var title: String {
    switch self {
    case .default: return "Default"
    case .compact: return "Compact"
    case .spacious: return "Spacious"
    }
  }
}

/// Alert-type identifiers used by the notification gate.
public enum AlertType: String, Codable, Sendable, CaseIterable {
  case highCPU
  case highMemory
  case highDisk
  case networkActivity
  case highTemperature
  case appNotResponding

  public var title: String {
    switch self {
    case .highCPU: return "High CPU Usage"
    case .highMemory: return "High Memory Usage"
    case .highDisk: return "High Disk Usage"
    case .networkActivity: return "Unusual Network Activity"
    case .highTemperature: return "High Temperature"
    case .appNotResponding: return "App Not Responding"
    }
  }

  public var subtitle: String {
    switch self {
    case .highCPU: return "CPU usage exceeds threshold."
    case .highMemory: return "Memory usage exceeds threshold."
    case .highDisk: return "Disk usage exceeds threshold."
    case .networkActivity: return "Unusual spikes in network traffic."
    case .highTemperature: return "Temperature exceeds threshold."
    case .appNotResponding: return "Applications stop responding."
    }
  }

  public var icon: String {
    switch self {
    case .highCPU: return "flame.fill"
    case .highMemory: return "exclamationmark.triangle.fill"
    case .highDisk: return "internaldrive.fill"
    case .networkActivity: return "waveform.path.ecg"
    case .highTemperature: return "thermometer.medium"
    case .appNotResponding: return "exclamationmark.triangle.fill"
    }
  }
}

/// Maps an incident metric to the alert type that gates its notifications.
/// Returns nil for metrics with no alert type: those notices are never
/// suppressed by the alert-type filter.
public func alertTypeID(forMetric metric: String?) -> AlertType? {
  switch metric {
  case "cpu": return .highCPU
  case "memory": return .highMemory
  case "disk": return .highDisk
  case "network": return .networkActivity
  case "temperature": return .highTemperature
  default: return nil
  }
}

/// Pure per-metric cadence gate for the collection tick.
public func metricIsDue(
  lastFire: Date?,
  now: Date,
  interval: TimeInterval,
  enabled: Bool
) -> Bool {
  guard enabled else {
    return false
  }
  guard let lastFire else {
    return true
  }
  return now.timeIntervalSince(lastFire) >= interval
}

/// User-facing settings for Ultimate Mac Monitor.
///
/// Numeric defaults come from the Ship-07 decisions
/// (`.scratch/ship-readiness/issues/07-fix-numeric-acceptance-decisions.md`).
/// This type is UI-free on purpose: the app target binds it to controls,
/// the tests drive it directly, and neither needs the other.
///
/// Every property carries a default value so settings persisted by older
/// versions (which stored fewer keys) still decode: missing keys fall back
/// to their defaults instead of discarding the whole file.
public struct MonitorSettings: Codable, Equatable, Sendable {
  public var launchAtLogin: Bool
  public var samplingInterval: TimeInterval

  // MARK: General
  public var monitoringMode: MonitoringMode = .normal
  public var checkForUpdates: Bool = true
  public var language: String = "en"
  public var maxCPU: Double = 0.10
  public var maxMemoryMB: Double = 500

  // MARK: Monitoring
  public var metricIntervals: [String: TimeInterval] = [
    "cpu": 1, "memory": 2, "disk": 5, "network": 2, "temperature": 2,
  ]
  /// Absent metric ⇒ monitored. Only explicit `false` disables collection.
  public var monitoredMetrics: [String: Bool] = [:]

  // MARK: Alerts
  public var notificationsEnabled: Bool = true
  public var macOSNotifications: Bool = true
  public var alertSound: Bool = true
  public var dockBadge: Bool = true
  public var thresholdCPU: Double = 0.85
  public var thresholdMemory: Double = 0.85
  public var thresholdDisk: Double = 0.90
  public var thresholdNetwork: Double = 100_000_000
  public var thresholdTemperature: Double = 85
  public var enabledAlertTypes: Set<AlertType> = Set(AlertType.allCases)

  // MARK: Data & Storage
  public var retentionDays: Int = 30
  public var storeMetrics: Bool = true
  public var storeIncidents: Bool = true
  public var storeLogs: Bool = true
  public var enableCache: Bool = true

  // MARK: Appearance
  public var theme: AppTheme = .auto
  public var accentColor: AccentColorName = .blue
  public var density: InterfaceDensity = .default
  public var showSidebarLabels: Bool = true
  public var compactSidebar: Bool = false
  public var reduceMotion: Bool = false

  // MARK: Privacy
  public var anonymousUsage: Bool = true
  public var crashReports: Bool = true
  public var includeSystemInfo: Bool = false
  public var hideSensitiveInfo: Bool = false

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

  public func isMonitored(_ metric: String) -> Bool {
    monitoredMetrics[metric] ?? true
  }

  public func threshold(for metric: String) -> Double {
    switch metric {
    case "cpu": return thresholdCPU
    case "memory": return thresholdMemory
    case "disk": return thresholdDisk
    default: return 0.9
    }
  }

  public func isAlertTypeEnabled(_ type: AlertType) -> Bool {
    enabledAlertTypes.contains(type)
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
    var next = settings
    next.samplingInterval = interval
    // Keep the mode in sync: each Ship-07 cadence belongs to exactly one mode.
    if let mode = MonitoringMode.allCases.first(where: { $0.samplingInterval == interval }) {
      next.monitoringMode = mode
    }
    update(next)
  }

  /// Plain persisted value: no side effects beyond persistence and the
  /// change handlers. The login item and sampling interval keep their
  /// dedicated setters because they touch system state.
  public func update<T>(_ keyPath: WritableKeyPath<MonitorSettings, T>, to value: T) {
    var next = settings
    next[keyPath: keyPath] = value
    guard next != settings else { return }
    update(next)
  }

  /// Monitoring mode drives the collection cadence through the same path
  /// as a direct interval change, so the timer restarts live.
  public func setMonitoringMode(_ mode: MonitoringMode) {
    guard mode != settings.monitoringMode else { return }
    var next = settings
    next.monitoringMode = mode
    next.samplingInterval = mode.samplingInterval
    update(next)
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
