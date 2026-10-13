import MonitoringEngine
import SwiftUI

/// Monitoring settings panel (issue 03): mode, per-metric sampling
/// intervals, monitored metric toggles, and resource limits. Interval and
/// toggle changes apply live through the collection tick's due-gating.
struct SettingsMonitoringPanel: View {
  @ObservedObject var viewModel: SettingsViewModel

  private let metrics: [(key: String, title: String, subtitle: String, icon: String, tint: Color)] = [
    ("cpu", "CPU Usage", "Total and per-core usage, frequency, and load.", "cpu", .blue),
    ("memory", "Memory", "Physical memory, swap, and pressure.", "memorychip", .purple),
    ("disk", "Disk", "Read/write activity and disk usage.", "internaldrive", .green),
    ("network", "Network", "Upload/download activity and connections.", "arrow.up.arrow.down", .orange),
    ("temperature", "Temperature", "CPU, GPU, and system temperatures (if available).", "thermometer.medium", .red),
  ]

  private let presets: [(name: String, intervals: [String: TimeInterval])] = [
    ("Balanced", ["cpu": 1, "memory": 2, "disk": 5, "network": 2, "temperature": 2]),
    ("High Detail", ["cpu": 1, "memory": 1, "disk": 1, "network": 1, "temperature": 1]),
    ("Low Overhead", ["cpu": 5, "memory": 5, "disk": 10, "network": 5, "temperature": 5]),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      monitoringModeCard(viewModel: viewModel)
      samplingIntervalsCard
      monitoredMetricsCard
      resourceLimitsCard(viewModel: viewModel)
    }
  }

  private var samplingIntervalsCard: some View {
    SettingsCard(
      title: "Sampling Intervals",
      subtitle: "Set how often data is collected for each metric."
    ) {
      VStack(spacing: 0) {
        HStack {
          Text("Presets")
            .font(.callout)
            .foregroundStyle(.secondary)
          Spacer()
          ForEach(presets, id: \.name) { preset in
            Button(preset.name) {
              viewModel.update(\.metricIntervals, to: preset.intervals)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
          }
        }
        .padding(.bottom, 8)
        ForEach(metrics, id: \.key) { metric in
          HStack(spacing: 12) {
            SettingsIcon(systemName: metric.icon, tint: metric.tint)
            Text(metric.title)
              .font(.callout)
              .frame(width: 90, alignment: .leading)
            Spacer()
            Slider(
              value: Binding(
                get: { viewModel.current.metricIntervals[metric.key] ?? 1 },
                set: { viewModel.setMetricInterval(metric.key, to: $0) }
              ),
              in: 1...10,
              step: 1
            )
            .frame(width: 180)
            Text("\(Int(viewModel.current.metricIntervals[metric.key] ?? 1)) second\(Int(viewModel.current.metricIntervals[metric.key] ?? 1) == 1 ? "" : "s")")
              .font(.callout.monospacedDigit())
              .foregroundStyle(.secondary)
              .frame(width: 80, alignment: .trailing)
          }
          .padding(.vertical, 6)
          Divider()
        }
      }
    }
  }

  private var monitoredMetricsCard: some View {
    SettingsCard(
      title: "Monitored Metrics",
      subtitle: "Choose which metrics to collect and display."
    ) {
      VStack(spacing: 0) {
        ForEach(metrics, id: \.key) { metric in
          SettingsToggleRow(
            icon: metric.icon,
            tint: metric.tint,
            title: metric.title,
            subtitle: metric.subtitle,
            isOn: Binding(
              get: { viewModel.current.isMonitored(metric.key) },
              set: { viewModel.setMonitored(metric.key, enabled: $0) }
            )
          )
          Divider()
        }
      }
    }
  }
}
