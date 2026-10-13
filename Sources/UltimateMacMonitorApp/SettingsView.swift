import Combine
import Foundation
import MonitoringEngine
import SwiftUI

/// Thin binding layer over SettingsStore: mirrors the store into @Published
/// values so the view stays declarative. All real logic (defaults,
/// persistence, the login-item service) lives in the store and is unit
/// tested there; this class only translates.
@MainActor
final class SettingsViewModel: ObservableObject {
  @Published var launchAtLogin: Bool
  @Published var samplingInterval: TimeInterval
  @Published var errorMessage: String?
  /// Full mirror for the settings center: panels bind to `$viewModel.current.<key>`.
  @Published var current: MonitorSettings

  private let store: SettingsStore

  init(store: SettingsStore) {
    self.store = store
    self.launchAtLogin = store.settings.launchAtLogin
    self.samplingInterval = store.settings.samplingInterval
    self.current = store.settings
    store.addChangeHandler { [weak self] settings in
      Task { @MainActor in
        self?.launchAtLogin = settings.launchAtLogin
        self?.samplingInterval = settings.samplingInterval
        self?.current = settings
      }
    }
  }

  /// Persists a plain settings value through the store.
  func update<T>(_ keyPath: WritableKeyPath<MonitorSettings, T>, to value: T) {
    store.update(keyPath, to: value)
    errorMessage = nil
  }

  func setMonitoringMode(_ mode: MonitoringMode) {
    store.setMonitoringMode(mode)
    errorMessage = nil
  }

  func setMetricInterval(_ metric: String, to interval: TimeInterval) {
    var intervals = current.metricIntervals
    intervals[metric] = interval
    store.update(\.metricIntervals, to: intervals)
    errorMessage = nil
  }

  func setMonitored(_ metric: String, enabled: Bool) {
    var flags = current.monitoredMetrics
    flags[metric] = enabled
    store.update(\.monitoredMetrics, to: flags)
    errorMessage = nil
  }

  func toggleAlertType(_ type: AlertType) {
    var enabled = current.enabledAlertTypes
    if enabled.contains(type) {
      enabled.remove(type)
    } else {
      enabled.insert(type)
    }
    store.update(\.enabledAlertTypes, to: enabled)
    errorMessage = nil
  }

  func resetAlertThresholds() {
    let defaults = MonitorSettings.ship07Defaults
    store.update(\.thresholdCPU, to: defaults.thresholdCPU)
    store.update(\.thresholdMemory, to: defaults.thresholdMemory)
    store.update(\.thresholdDisk, to: defaults.thresholdDisk)
    store.update(\.thresholdNetwork, to: defaults.thresholdNetwork)
    store.update(\.thresholdTemperature, to: defaults.thresholdTemperature)
    errorMessage = nil
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    guard enabled != store.settings.launchAtLogin else { return }
    do {
      try store.setLaunchAtLogin(enabled)
      errorMessage = nil
    } catch {
      // Revert the toggle: the service refused, so the UI must not lie.
      launchAtLogin = store.settings.launchAtLogin
      errorMessage =
        "Could not \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)"
    }
  }

  func setSamplingInterval(_ interval: TimeInterval) {
    guard interval != store.settings.samplingInterval else { return }
    store.setSamplingInterval(interval)
    // The store ignores unknown cadences; mirror back what it kept.
    samplingInterval = store.settings.samplingInterval
    errorMessage = nil
  }

  func restoreDefaults() {
    do {
      try store.restoreDefaults()
      errorMessage = nil
    } catch {
      launchAtLogin = store.settings.launchAtLogin
      samplingInterval = store.settings.samplingInterval
      errorMessage = "Could not restore defaults: \(error.localizedDescription)"
    }
  }
}

/// Minimal settings window for issue 19: every control is wired, no dead
/// controls. Opened from the gear button in the menu-bar popover.
struct SettingsView: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    Form {
      Section("General") {
        logoPlaceholder
        Toggle("Launch at login", isOn: $viewModel.launchAtLogin)
          .onChange(of: viewModel.launchAtLogin) { viewModel.setLaunchAtLogin($0) }
          .help("Start Ultimate Mac Monitor when you log in.")
      }
      Section("Monitoring") {
        Picker("Sampling interval", selection: $viewModel.samplingInterval) {
          ForEach(MonitorSettings.intervalOptions, id: \.self) { interval in
            Text(MonitorSettings.label(for: interval)).tag(interval)
          }
        }
        .pickerStyle(.radioGroup)
        .onChange(of: viewModel.samplingInterval) { viewModel.setSamplingInterval($0) }
        .help("Restarts collection at the chosen cadence.")
      }
      Section("Defaults") {
        Button("Restore Ship-07 defaults") {
          viewModel.restoreDefaults()
        }
        Text("Sampling 1.0s, launch at login off — the decided Ship-07 numbers.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if let error = viewModel.errorMessage {
        Text(error)
          .font(.callout)
          .foregroundStyle(.red)
      }
    }
    .formStyle(.grouped)
    .padding()
    .frame(width: 420)
  }

  private var logoPlaceholder: some View {
    HStack(spacing: 12) {
      AppLogo(size: 48)
      VStack(alignment: .leading, spacing: 2) {
        Text("Ultimate Mac Monitor").font(.headline)
        Text("Version \(SystemInfo.appVersion)").font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}
