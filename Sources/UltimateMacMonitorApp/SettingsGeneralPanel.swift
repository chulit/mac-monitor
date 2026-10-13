import MonitoringEngine
import SwiftUI

/// General settings panel (issue 02): app behavior, monitoring mode,
/// resource limits, and reset. "Show in menu bar" is intentionally absent:
/// this build has no menu-bar UI, so the toggle could not be honest.
struct SettingsGeneralPanel: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      appBehaviorCard
      monitoringModeCard(viewModel: viewModel)
      resourceLimitsCard(viewModel: viewModel)
      resetCard
      if let error = viewModel.errorMessage {
        Text(error)
          .font(.callout)
          .foregroundStyle(.red)
      }
    }
  }

  private var appBehaviorCard: some View {
    SettingsCard(title: "App Behavior") {
      VStack(spacing: 0) {
        HStack(spacing: 12) {
          SettingsIcon(systemName: "power", tint: .blue)
          VStack(alignment: .leading, spacing: 2) {
            Text("Launch at login")
              .font(.callout)
            Text("Start Ultimate Mac Monitor automatically when you log in.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Toggle(
            "",
            isOn: Binding(
              get: { viewModel.launchAtLogin },
              set: { viewModel.setLaunchAtLogin($0) }
            )
          )
          .labelsHidden()
          .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
        Divider()
        SettingsToggleRow(
          icon: "arrow.triangle.2.circlepath",
          tint: .green,
          title: "Check for updates automatically",
          subtitle: "Check GitHub releases when the app starts.",
          isOn: viewModel.binding(\.checkForUpdates)
        )
        Divider()
        HStack(spacing: 12) {
          SettingsIcon(systemName: "globe", tint: .purple)
          VStack(alignment: .leading, spacing: 2) {
            Text("Language")
              .font(.callout)
            Text("Change the app language.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Picker("", selection: .constant("en")) {
            Text("English").tag("en")
          }
          .pickerStyle(.menu)
          .disabled(true)
          .help("English is the only language in this version.")
        }
        .padding(.vertical, 4)
      }
    }
  }

  private var resetCard: some View {
    SettingsCard(title: "Reset") {
      HStack(spacing: 12) {
        SettingsIcon(systemName: "arrow.counterclockwise", tint: .orange)
        VStack(alignment: .leading, spacing: 2) {
          Text("Reset Settings")
            .font(.callout)
          Text("Restore all settings to default values.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Reset to Default") {
          viewModel.restoreDefaults()
        }
        .buttonStyle(.bordered)
      }
    }
  }
}

/// Monitoring mode selector boxes, shared by the General and Monitoring panels.
func monitoringModeCard(viewModel: SettingsViewModel) -> some View {
  SettingsCard(title: "Monitoring Mode") {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        ForEach(MonitoringMode.allCases, id: \.self) { mode in
          Button {
            viewModel.setMonitoringMode(mode)
          } label: {
            VStack(alignment: .leading, spacing: 4) {
              HStack(spacing: 6) {
                Image(
                  systemName: viewModel.current.monitoringMode == mode
                    ? "largecircle.fill.circle" : "circle"
                )
                .foregroundStyle(
                  viewModel.current.monitoringMode == mode ? Color.accentColor : .secondary
                )
                Text(mode.title)
                  .font(.callout.bold())
              }
              Text(mode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
              Text(MonitorSettings.label(for: mode.samplingInterval))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              viewModel.current.monitoringMode == mode
                ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05),
              in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(
                  viewModel.current.monitoringMode == mode
                    ? Color.accentColor.opacity(0.5) : Color.clear,
                  lineWidth: 1
                )
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(mode.title) monitoring mode")
        }
      }
      Text("Collection restarts at the new cadence immediately.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

/// Resource limit sliders, shared by the General and Monitoring panels.
func resourceLimitsCard(viewModel: SettingsViewModel) -> some View {
  SettingsCard(
    title: "Resource Limits",
    subtitle: "Set limits to keep monitoring lightweight."
  ) {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        SettingsIcon(systemName: "cpu", tint: .blue)
        VStack(alignment: .leading, spacing: 2) {
          Text("Max CPU Usage")
            .font(.callout)
          Text("Monitoring degrades to reduced sampling past this budget.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Slider(
          value: viewModel.binding(\.maxCPU),
          in: 0.01...0.20,
          step: 0.01
        )
        .frame(width: 180)
        Text("\(Int((viewModel.current.maxCPU * 100).rounded()))%")
          .font(.callout.monospacedDigit())
          .frame(width: 44, alignment: .trailing)
      }
      HStack(spacing: 12) {
        SettingsIcon(systemName: "memorychip", tint: .purple)
        VStack(alignment: .leading, spacing: 2) {
          Text("Max Memory Usage")
            .font(.callout)
          Text("Not enforced yet — stored as a preference.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Slider(
          value: viewModel.binding(\.maxMemoryMB),
          in: 100...2000,
          step: 50
        )
        .frame(width: 180)
        Text("\(Int(viewModel.current.maxMemoryMB)) MB")
          .font(.callout.monospacedDigit())
          .frame(width: 64, alignment: .trailing)
      }
    }
  }
}
