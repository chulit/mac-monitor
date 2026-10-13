import SwiftUI
import MonitoringEngine

/// Menu-bar popover following `docs/plans/design/1. menu-bar`: header,
/// metric cards, active incidents, monitoring mode, and action buttons.
/// Cards show live data where collectors exist and honest unavailable
/// states where they don't (temperature needs sensor research).
struct PopoverView: View {
  @ObservedObject var controller: EngineController
  var openSection: (AppSection) -> Void
  var onQuit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      // BISECT ROUND 3 (Ship-21): header only. Cards (incl. Sparkline)
      // rejoin one by one if this lives.
    }
    .padding(14)
    .frame(width: 640)
  }

  private var header: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 10)
        .fill(Color(red: 0.1, green: 0.12, blue: 0.35))
        .frame(width: 40, height: 40)
        .overlay(Image(systemName: "waveform").foregroundStyle(.white))
      VStack(alignment: .leading, spacing: 2) {
        Text("Ultimate Mac Monitor").font(.headline)
        if let evaluation = controller.evaluation {
          let status = makeMonitoringStatus(evaluation.observation)
          HStack(spacing: 4) {
            Circle().fill(statusColor(status.headline)).frame(width: 7, height: 7)
            Text(status.headline).font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }
      Spacer()
    }
  }

  private var cards: some View {
    HStack(spacing: 10) {
      metricCard(title: "CPU", icon: "cpu", tint: .blue, value: percent(controller.cpuShare), history: controller.cpuHistory)
      metricCard(title: "Memory", icon: "memorychip", tint: .purple, value: percent(controller.memoryHistory.last?.value), history: controller.memoryHistory)
      metricCard(title: "Disk", icon: "internaldrive", tint: .green, value: percent(controller.diskHistory.last?.value), history: controller.diskHistory)
      metricCard(title: "Network", icon: "arrow.up.arrow.down", tint: .blue, value: rate(controller.networkHistory.last?.value), history: controller.networkHistory)
      temperatureCard
    }
  }

  private func metricCard(
    title: String,
    icon: String,
    tint: Color,
    value: String,
    history: [(date: Date, value: Double)]
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
        Text(title).font(.caption).foregroundStyle(.secondary)
      }
      Text(value).font(.title3.bold().monospacedDigit())
      Sparkline(values: history, tint: tint)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
  }

  private var temperatureCard: some View {
    Group {
      if controller.temperatureFresh, let last = controller.temperatureHistory.last {
        metricCard(
          title: "Temperature",
          icon: "thermometer",
          tint: .orange,
          value: "\(Int(last.value.rounded()))°",
          history: controller.temperatureHistory
        )
      } else {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 4) {
            Image(systemName: "thermometer").font(.caption).foregroundStyle(.secondary)
            Text("Temperature").font(.caption).foregroundStyle(.secondary)
          }
          Text("–").font(.title3.bold().monospacedDigit())
          Text("Unavailable on this Mac")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(height: 28, alignment: .top)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      }
    }
  }

  @State private var temperatureExpanded = true

  private var temperatureDetail: some View {
    Group {
      if controller.temperatureFresh {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 6) {
            Image(systemName: "thermometer").font(.callout)
            Text("Temperature").font(.headline)
            Spacer()
            Image(systemName: temperatureExpanded ? "chevron.up" : "chevron.down")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .contentShape(Rectangle())
          .onTapGesture { temperatureExpanded.toggle() }
          if temperatureExpanded {
            temperatureRow(label: "CPU (Average)", value: controller.temperatureHistory.last?.value)
            temperatureRow(label: "CPU (Performance)", value: nil)
            temperatureRow(label: "CPU (Efficiency)", value: nil)
            temperatureRow(label: "CPU (Secondary sensor)", value: controller.temperatureSecondaryHistory.last?.value)
            temperatureRow(label: "GPU", value: nil)
            temperatureRow(label: "SSD", value: controller.temperatureStorageHistory.last?.value)
          }
        }
      }
    }
  }

  private func temperatureRow(label: String, value: Double?) -> some View {
    HStack {
      Text(label)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 150, alignment: .leading)
      if let value {
        GeometryReader { geometry in
          RoundedRectangle(cornerRadius: 3)
            .fill(Color.orange.opacity(0.25))
            .frame(height: 8)
            .overlay(alignment: .leading) {
              RoundedRectangle(cornerRadius: 3)
                .fill(Color.orange)
                .frame(width: geometry.size.width * min(max(value / 100, 0), 1), height: 8)
            }
        }
        .frame(height: 8)
        Text("\(Int(value.rounded()))°C")
          .font(.callout.monospacedDigit())
          .frame(width: 48, alignment: .trailing)
      } else {
        Text("unavailable")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Spacer()
      }
    }
  }

  private func incidentsSection(_ active: [Incident]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: "bell").font(.callout)
        Text("Active Incidents").font(.headline)
        Spacer()
        Button("See All") { openSection(.investigation) }
          .buttonStyle(.link)
          .font(.callout)
      }
      ForEach(Array(active.prefix(3).enumerated()), id: \.offset) { _, incident in
        let name = controller.evaluation?.timelines.first { $0.incident == incident }?
          .relevantProcesses.first?.process.name ?? "System"
        HStack {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.red.opacity(0.15))
            .frame(width: 28, height: 28)
            .overlay(Image(systemName: "waveform.path.ecg").font(.caption).foregroundStyle(.red))
          VStack(alignment: .leading) {
            Text(incidentTitle(incident)).font(.callout)
            Text(name).font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
        }
      }
    }
  }

  private var modeSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "waveform.path").font(.callout)
        Text("Monitoring Mode").font(.headline)
      }
      HStack(spacing: 10) {
        modeCard(title: "Normal", caption: "Balanced for everyday use", active: currentMode == .normal, tint: .blue)
        modeCard(title: "Reduced", caption: "Lower overhead", active: currentMode == .reduced, tint: .gray)
        modeCard(title: "High Detail", caption: "More data for investigation", active: currentMode == .highDetail, tint: .orange)
      }
      HStack {
        Text("Auto reverts after 10 minutes")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Start for 10 Minutes") {
          controller.requestHighDetail(seconds: 600)
        }
        .buttonStyle(.bordered)
        .font(.callout)
        .disabled(currentMode == .highDetail)
      }
    }
  }

  private var actionRow: some View {
    HStack(spacing: 10) {
      actionButton(title: "Open App", icon: "square.grid.2x2") { openSection(.dashboard) }
      actionButton(title: "Process Viewer", icon: "list.bullet") { openSection(.processes) }
      actionButton(title: "System Health", icon: "waveform.path.ecg") { openSection(.investigation) }
    }
  }

  private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: icon)
        Text(title)
      }
      .font(.callout)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private enum ModeState {
    case normal, reduced, highDetail
  }

  private var currentMode: ModeState {
    switch controller.evaluation?.observation?.mode {
    case .reduced: return .reduced
    case .highDetail: return .highDetail
    default: return .normal
    }
  }

  private func modeCard(title: String, caption: String, active: Bool, tint: Color) -> some View {
    HStack(spacing: 6) {
      Circle().fill(active ? tint : Color.gray.opacity(0.4)).frame(width: 8, height: 8)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.callout.bold())
        Text(caption).font(.caption2).foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(modeCardBackground(active: active, tint: tint), in: RoundedRectangle(cornerRadius: 10))
  }

  private func modeCardBackground(active: Bool, tint: Color) -> Color {
    if active {
      return tint.opacity(0.12)
    }
    return Color.gray.opacity(0.15)
  }

  private func percent(_ value: Double?) -> String {
    value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
  }

  private func rate(_ value: Double?) -> String {
    value.map(formatRate) ?? "–"
  }

  private func incidentTitle(_ incident: Incident) -> String {
    switch incident.source {
    case .rule: return "Threshold breach"
    case .baseline: return "Unusual behavior"
    }
  }

  private func statusColor(_ headline: String) -> Color {
    switch headline {
    case "Reduced monitoring": return .orange
    case "High-detail investigation": return .blue
    default: return .green
    }
  }
}
