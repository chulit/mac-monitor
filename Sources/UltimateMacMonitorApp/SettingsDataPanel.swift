import AppKit
import MonitoringEngine
import SwiftUI

/// Data & Storage panel (issue 05): retention, real storage usage, data
/// options, and disk management. Every number comes from the retention
/// store, the log file, or the chart buffers — never invented.
struct SettingsDataPanel: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var controller: EngineController
  @State private var showClearHistoryConfirm = false
  @State private var showClearCacheConfirm = false

  private let retentionOptions = [7, 30, 90]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      retentionCard
      storageUsageCard
      dataOptionsCard
      diskManagementCard
    }
    .alert("Clear History?", isPresented: $showClearHistoryConfirm) {
      Button("Clear History", role: .destructive) {
        controller.clearHistory()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This deletes all recorded metrics and incidents. This cannot be undone.")
    }
    .alert("Clear Cache?", isPresented: $showClearCacheConfirm) {
      Button("Clear Cache", role: .destructive) {
        controller.clearCache()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This clears the in-memory chart buffers. Live collection continues.")
    }
  }

  private var retentionCard: some View {
    SettingsCard(
      title: "Data Retention",
      subtitle: "Choose how long historical data is kept on your Mac."
    ) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          ForEach(retentionOptions, id: \.self) { days in
            retentionBox(days: days, title: "\(days) Days", subtitle: "Save data for \(days) days")
          }
          retentionBox(days: -1, title: "Custom", subtitle: "Set a custom period")
        }
        if !retentionOptions.contains(viewModel.current.retentionDays) {
          HStack {
            Text("Custom retention")
              .font(.callout)
            Spacer()
            Stepper(
              "\(viewModel.current.retentionDays) days",
              value: viewModel.binding(\.retentionDays),
              in: 1...365
            )
            .frame(width: 200)
          }
        }
        HStack(spacing: 8) {
          Image(systemName: "info.circle.fill")
            .foregroundStyle(.blue)
          Text("Older data will be automatically deleted to save disk space.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  private func retentionBox(days: Int, title: String, subtitle: String) -> some View {
    let selected = days == -1
      ? !retentionOptions.contains(viewModel.current.retentionDays)
      : viewModel.current.retentionDays == days
    return SettingsOptionBox(
      title: title,
      subtitle: subtitle,
      selected: selected,
      action: {
        viewModel.update(\.retentionDays, to: days == -1 ? 14 : days)
      }
    )
  }

  private var storageUsageCard: some View {
    let snapshot = controller.historySnapshot()
    let metricSamples = snapshot?.details.count ?? 0
    let incidents = snapshot?.incidents.count ?? 0
    let logBytes = AppLog.logFileSize ?? 0
    let cachePoints = controller.cpuHistory.count + controller.memoryHistory.count
      + controller.diskHistory.count + controller.networkHistory.count
      + controller.temperatureHistory.count
    let segments: [(label: String, count: Int, tint: Color)] = [
      ("Metrics", metricSamples, .blue),
      ("Incidents", incidents, .purple),
      ("Cache", cachePoints, .green),
    ]
    let total = max(segments.map(\.count).reduce(0, +), 1)
    return SettingsCard(
      title: "Storage Usage",
      subtitle: "Current usage by data type."
    ) {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Spacer()
          Text("\(metricSamples) samples")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        GeometryReader { geometry in
          HStack(spacing: 2) {
            ForEach(segments, id: \.label) { segment in
              RoundedRectangle(cornerRadius: 3)
                .fill(segment.tint)
                .frame(width: max(geometry.size.width * Double(segment.count) / Double(total), segment.count > 0 ? 4 : 0))
            }
          }
        }
        .frame(height: 10)
        HStack(spacing: 16) {
          ForEach(segments, id: \.label) { segment in
            HStack(spacing: 6) {
              Circle()
                .fill(segment.tint)
                .frame(width: 8, height: 8)
              VStack(alignment: .leading, spacing: 1) {
                Text(segment.label)
                  .font(.caption)
                Text("\(segment.count)")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 1) {
            Text("Logs")
              .font(.caption)
            Text(formatBytes(logBytes))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "Storage: \(metricSamples) metric samples, \(incidents) incidents, \(cachePoints) cached points, logs \(formatBytes(logBytes))"
        )
      }
    }
  }

  private func formatBytes(_ bytes: Int) -> String {
    if bytes >= 1_000_000 {
      return String(format: "%.1f MB", Double(bytes) / 1_000_000)
    }
    if bytes >= 1_000 {
      return String(format: "%.0f KB", Double(bytes) / 1_000)
    }
    return "\(bytes) B"
  }

  private var dataOptionsCard: some View {
    SettingsCard(
      title: "Data Options",
      subtitle: "Configure what data is stored on disk."
    ) {
      VStack(spacing: 0) {
        SettingsToggleRow(
          icon: "waveform.path.ecg", tint: .blue,
          title: "Store System Metrics",
          subtitle: "Save historical CPU, memory, disk, network, and temperature data.",
          isOn: viewModel.binding(\.storeMetrics)
        )
        Divider()
        SettingsToggleRow(
          icon: "bell", tint: .orange,
          title: "Store Incidents",
          subtitle: "Keep a history of detected anomalies and system events.",
          isOn: viewModel.binding(\.storeIncidents)
        )
        Divider()
        SettingsToggleRow(
          icon: "doc.text", tint: .gray,
          title: "Store Logs",
          subtitle: "Save the debug log for troubleshooting.",
          isOn: viewModel.binding(\.storeLogs)
        )
        Divider()
        SettingsToggleRow(
          icon: "trash", tint: .red,
          title: "Enable Cache",
          subtitle: "Keep in-memory chart buffers for smooth graphs.",
          isOn: viewModel.binding(\.enableCache)
        )
      }
    }
  }

  private var diskManagementCard: some View {
    SettingsCard(
      title: "Disk Management",
      subtitle: "Manually manage stored data and free up space."
    ) {
      VStack(spacing: 8) {
        HStack {
          Spacer()
          Button {
            if let folder = AppLog.dataFolder {
              NSWorkspace.shared.open(folder)
            }
          } label: {
            Label("Open Data Folder", systemImage: "folder")
              .font(.callout)
          }
          .buttonStyle(.bordered)
          .disabled(AppLog.dataFolder == nil)
        }
        HStack(spacing: 8) {
          clearButton(
            title: "Clear History",
            subtitle: "Delete all historical data.",
            action: { showClearHistoryConfirm = true }
          )
          clearButton(
            title: "Clear Cache",
            subtitle: "Remove cached data only.",
            action: { showClearCacheConfirm = true }
          )
        }
      }
    }
  }

  private func clearButton(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: "trash")
          .foregroundStyle(.red)
          .frame(width: 28, height: 28)
          .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        VStack(alignment: .leading, spacing: 1) {
          Text(title)
            .font(.callout)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
