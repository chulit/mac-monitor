import MonitoringEngine
import SwiftUI

/// Alert & Notifications panel (issue 04): master toggle, channels,
/// thresholds, and alert types. Threshold changes rebuild the detection
/// rules live; network/temperature thresholds are stored for future
/// detectors — only CPU/Memory/Disk drive incidents today.
struct SettingsAlertsPanel: View {
  @ObservedObject var viewModel: SettingsViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      masterToggleCard
      channelsCard
      thresholdsCard
      alertTypesCard
    }
  }

  private var masterToggleCard: some View {
    SettingsCard(title: "Notifications") {
      SettingsToggleRow(
        icon: "bell.fill",
        tint: .blue,
        title: "Enable Notifications",
        subtitle: "Receive alerts for system anomalies and important events.",
        isOn: viewModel.binding(\.notificationsEnabled)
      )
    }
  }

  private var channelsCard: some View {
    SettingsCard(
      title: "Alert Channels",
      subtitle: "Choose how you want to be notified."
    ) {
      VStack(spacing: 0) {
        SettingsToggleRow(
          icon: "bell",
          tint: .blue,
          title: "macOS Notifications",
          subtitle: "Show notifications in Notification Center.",
          isOn: viewModel.binding(\.macOSNotifications)
        )
        Divider()
        SettingsToggleRow(
          icon: "speaker.wave.2",
          tint: .orange,
          title: "Sound",
          subtitle: "Play a sound for critical alerts.",
          isOn: viewModel.binding(\.alertSound)
        )
        Divider()
        SettingsToggleRow(
          icon: "app.badge",
          tint: .purple,
          title: "Badge on Dock",
          subtitle: "Show the active incident count on the Dock icon.",
          isOn: viewModel.binding(\.dockBadge)
        )
      }
    }
    .opacity(viewModel.current.notificationsEnabled ? 1 : 0.5)
  }

  private var thresholdsCard: some View {
    SettingsCard(
      title: "Alert Thresholds",
      subtitle: "Set when to trigger alerts for each metric."
    ) {
      VStack(spacing: 0) {
        HStack {
          Spacer()
          Button("Reset to Default") {
            viewModel.resetAlertThresholds()
          }
          .buttonStyle(.bordered)
          .controlSize(.small)
        }
        .padding(.bottom, 4)
        thresholdSlider(
          icon: "cpu", tint: .blue, title: "CPU Usage",
          value: viewModel.binding(\.thresholdCPU),
          range: 0.5...1.0, display: "\(Int(viewModel.current.thresholdCPU * 100)) %"
        )
        thresholdSlider(
          icon: "memorychip", tint: .purple, title: "Memory Usage",
          value: viewModel.binding(\.thresholdMemory),
          range: 0.5...1.0, display: "\(Int(viewModel.current.thresholdMemory * 100)) %"
        )
        thresholdSlider(
          icon: "internaldrive", tint: .green, title: "Disk Usage",
          value: viewModel.binding(\.thresholdDisk),
          range: 0.5...1.0, display: "\(Int(viewModel.current.thresholdDisk * 100)) %"
        )
        thresholdSlider(
          icon: "arrow.up.arrow.down", tint: .orange, title: "Network Usage",
          value: viewModel.binding(\.thresholdNetwork),
          range: 1_000_000...500_000_000, step: 1_000_000,
          display: "\(Int(viewModel.current.thresholdNetwork / 1_000_000)) MB/s"
        )
        thresholdSlider(
          icon: "thermometer.medium", tint: .red, title: "Temperature",
          value: viewModel.binding(\.thresholdTemperature),
          range: 50...100, step: 1,
          display: "\(Int(viewModel.current.thresholdTemperature)) °C"
        )
        Text("Network and temperature thresholds are stored for future detectors — only CPU, Memory, and Disk drive incidents today.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.top, 8)
      }
    }
  }

  private func thresholdSlider(
    icon: String, tint: Color, title: String,
    value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0.01,
    display: String
  ) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        SettingsIcon(systemName: icon, tint: tint)
        Text(title)
          .font(.callout)
          .frame(width: 120, alignment: .leading)
        Spacer()
        Slider(value: value, in: range, step: step)
          .frame(width: 180)
        Text(display)
          .font(.callout.monospacedDigit())
          .frame(width: 70, alignment: .trailing)
          .padding(4)
          .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
      }
      .padding(.vertical, 6)
      Divider()
    }
  }

  private var alertTypesCard: some View {
    SettingsCard(
      title: "Alert Types",
      subtitle: "Choose which events should trigger notifications."
    ) {
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
        ForEach(AlertType.allCases, id: \.self) { type in
          HStack(spacing: 10) {
            Button {
              viewModel.toggleAlertType(type.rawValue)
            } label: {
              Image(
                systemName: viewModel.current.isAlertTypeEnabled(type.rawValue)
                  ? "checkmark.square.fill" : "square"
              )
              .foregroundStyle(
                viewModel.current.isAlertTypeEnabled(type.rawValue)
                  ? Color.accentColor : .secondary
              )
              .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(type.title)
            SettingsIcon(systemName: type.icon, tint: .secondary)
            VStack(alignment: .leading, spacing: 1) {
              Text(type.title)
                .font(.callout)
              Text(type.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }
          .padding(.vertical, 6)
        }
      }
      Text("App Not Responding is not detected by the engine yet — its toggle is stored for when detection lands.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }
  }
}
