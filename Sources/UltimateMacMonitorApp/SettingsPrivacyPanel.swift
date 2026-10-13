import AppKit
import MonitoringEngine
import SwiftUI

/// Privacy & Security panel (issue 07): real permission statuses, data
/// privacy toggles, and clear-data. "Require Password" is intentionally
/// absent: there is no app-lock implementation, and a fake security
/// control would be worse than none.
struct SettingsPrivacyPanel: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var controller: EngineController
  @State private var showClearAllConfirm = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      permissionsCard
      dataPrivacyCard
      securityCard
      resetCard
    }
    .alert("Clear All Data?", isPresented: $showClearAllConfirm) {
      Button("Clear All Data", role: .destructive) {
        controller.clearHistory()
        controller.clearCache()
        viewModel.restoreDefaults()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This deletes all historical data, cached files, and resets settings. This cannot be undone.")
    }
  }

  private var permissionsCard: some View {
    SettingsCard(
      title: "Permissions",
      subtitle: "Manage the permissions required for monitoring system resources."
    ) {
      VStack(spacing: 0) {
        permissionRow(
          icon: "waveform.path.ecg",
          title: "System Monitoring",
          subtitle: "Required to read CPU, memory, disk, and network statistics.",
          granted: controller.isCollecting,
          detail: controller.isCollecting ? "Collecting" : "Paused"
        )
        Divider()
        permissionRow(
          icon: "thermometer.medium",
          title: "Sensor Access",
          subtitle: "Required to read temperature sensors (CPU, GPU, etc.).",
          granted: true,
          detail: controller.temperatureFresh ? "Reading sensors" : "No permission needed"
        )
        Divider()
        permissionRow(
          icon: "chart.line.uptrend.xyaxis",
          title: "Process Information",
          subtitle: "Required to read running processes and their resource usage.",
          granted: !controller.processes.isEmpty,
          detail: !controller.processes.isEmpty
            ? "\(controller.processes.count) processes visible" : "Waiting for data"
        )
      }
    }
  }

  private func permissionRow(
    icon: String, title: String, subtitle: String, granted: Bool, detail: String
  ) -> some View {
    Button {
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
        NSWorkspace.shared.open(url)
      }
    } label: {
      HStack(spacing: 12) {
        SettingsIcon(systemName: icon, tint: .blue)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.callout)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        HStack(spacing: 4) {
          Image(systemName: granted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(granted ? Color.green : .secondary)
          Text(granted ? "Granted" : "Pending")
            .font(.callout)
            .foregroundStyle(granted ? Color.green : .secondary)
        }
        .help(detail)
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 6)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(title): \(granted ? "granted" : "pending"). \(detail)")
  }

  private var dataPrivacyCard: some View {
    SettingsCard(
      title: "Data Privacy",
      subtitle: "Control what data is collected and how it is used."
    ) {
      VStack(spacing: 0) {
        SettingsToggleRow(
          icon: "chart.bar",
          tint: .blue,
          title: "Anonymous Usage Data",
          subtitle: "Help improve Ultimate Mac Monitor by sharing anonymous usage data.",
          isOn: viewModel.binding(\.anonymousUsage)
        )
        Divider()
        SettingsToggleRow(
          icon: "doc.text",
          tint: .gray,
          title: "Crash Reports",
          subtitle: "Automatically send crash reports to help us fix issues.",
          isOn: viewModel.binding(\.crashReports)
        )
        Divider()
        SettingsToggleRow(
          icon: "cpu",
          tint: .purple,
          title: "Include System Information",
          subtitle: "Include basic system information with crash reports.",
          isOn: viewModel.binding(\.includeSystemInfo)
        )
        Text("No analytics or crash reports are transmitted in this version — these preferences are stored for when telemetry exists.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 8)
      }
    }
  }

  private var securityCard: some View {
    SettingsCard(
      title: "Security",
      subtitle: "Protect your data and control access to the app."
    ) {
      SettingsToggleRow(
        icon: "eye.slash",
        tint: .orange,
        title: "Hide Sensitive Information",
        subtitle: "Hide process names and file paths in UI screenshots and exports.",
        isOn: viewModel.binding(\.hideSensitiveInfo)
      )
    }
  }

  private var resetCard: some View {
    SettingsCard(
      title: "Reset & Clear Data",
      subtitle: "Remove all stored data and reset security settings."
    ) {
      HStack(spacing: 12) {
        SettingsIcon(systemName: "trash", tint: .red)
        VStack(alignment: .leading, spacing: 2) {
          Text("Clear All Data")
            .font(.callout)
          Text("Delete all historical data, cached files, and reset settings.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Clear Data…") {
          showClearAllConfirm = true
        }
        .buttonStyle(.bordered)
        .tint(.red)
      }
    }
  }
}
