import SwiftUI
import MonitoringEngine

/// Menu-bar popover following `docs/plans/design/1. menu-bar`: header,
/// metric cards, temperature detail, active incidents, monitoring mode,
/// and action buttons. Cards show live data where collectors exist and
/// honest unavailable states where they don't (performance/efficiency
/// cluster and GPU sensors do not exist on this model).
struct PopoverView: View {
  @ObservedObject var controller: EngineController
  var openSection: (AppSection) -> Void
  var onOpenSettings: () -> Void
  var onQuit: () -> Void

  @State private var temperatureExpanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      cards
      temperatureSection
      incidentsSection
      modeSection
      actionRow
    }
    .padding(16)
    .frame(width: 700)
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 12) {
      RoundedRectangle(cornerRadius: 12)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.04, green: 0.06, blue: 0.18),
              Color(red: 0.10, green: 0.16, blue: 0.45),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 44, height: 44)
        .overlay(
          Image(systemName: "waveform")
            .font(.title3)
            .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))
        )
      VStack(alignment: .leading, spacing: 3) {
        Text("Ultimate Mac Monitor").font(.title3.bold())
        if let evaluation = controller.evaluation {
          let status = makeMonitoringStatus(evaluation.observation)
          HStack(spacing: 6) {
            Circle().fill(statusColor(status.headline)).frame(width: 8, height: 8)
            Text(status.headline).font(.subheadline).foregroundStyle(.secondary)
          }
        }
      }
      Spacer()
      Button {
        onOpenSettings()
      } label: {
        Image(systemName: "gearshape")
          .font(.body)
          .foregroundStyle(.primary)
          .frame(width: 36, height: 36)
          .background(.thinMaterial, in: Circle())
          .overlay(Circle().stroke(Color.gray.opacity(0.15)))
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Settings")
    }
  }

  // MARK: Metric cards

  private var cards: some View {
    HStack(spacing: 10) {
      metricCard(
        title: "CPU", icon: "cpu", tint: .blue,
        value: percent(controller.cpuShare), history: controller.cpuHistory
      )
      metricCard(
        title: "Memory", icon: "memorychip", tint: .purple,
        value: percent(controller.memoryHistory.last?.value), history: controller.memoryHistory
      )
      metricCard(
        title: "Disk", icon: "internaldrive", tint: .green,
        value: percent(controller.diskHistory.last?.value), history: controller.diskHistory
      )
      metricCard(
        title: "Network", icon: "arrow.up.arrow.down", tint: .blue,
        value: rate(controller.networkHistory.last?.value), history: controller.networkHistory
      )
      metricCard(
        title: "Temperature", icon: "thermometer", tint: .orange,
        value: temperatureValue, history: controller.temperatureHistory
      )
    }
  }

  private func metricCard(
    title: String,
    icon: String,
    tint: Color,
    value: String,
    history: [(date: Date, value: Double)]
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(tint)
          .frame(width: 24, height: 24)
          .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        Text(title).font(.caption).foregroundStyle(.secondary)
      }
      Text(value).font(.title2.bold().monospacedDigit())
      Sparkline(values: history, tint: tint)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
  }

  private var temperatureValue: String {
    guard controller.temperatureFresh, let last = controller.temperatureHistory.last else {
      return "–"
    }
    return "\(Int(last.value.rounded()))°C"
  }

  // MARK: Temperature detail

  private var temperatureSection: some View {
    sectionCard {
      VStack(alignment: .leading, spacing: 12) {
        Button {
          temperatureExpanded.toggle()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "thermometer").font(.callout).foregroundStyle(.orange)
            Text("Temperature").font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        if temperatureExpanded {
          temperatureRow(label: "CPU (Average)", value: controller.temperatureHistory.last?.value)
          temperatureRow(label: "CPU (Performance)", value: nil)
          temperatureRow(label: "CPU (Efficiency)", value: nil)
          temperatureRow(label: "GPU", value: nil)
          temperatureRow(label: "SSD", value: controller.temperatureStorageHistory.last?.value)
        }
      }
    }
  }

  private func temperatureRow(label: String, value: Double?) -> some View {
    HStack(spacing: 12) {
      Text(label)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 170, alignment: .leading)
      if let value {
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.gray.opacity(0.18))
            Capsule()
              .fill(Color.orange)
              .frame(width: geometry.size.width * min(max(value / 100, 0), 1))
          }
        }
        .frame(height: 10)
        Text("\(Int(value.rounded()))°C")
          .font(.callout.monospacedDigit())
          .frame(width: 60, alignment: .trailing)
      } else {
        Text("Unavailable on this Mac")
          .font(.callout)
          .foregroundStyle(.tertiary)
        Spacer()
        Text("–")
          .font(.callout)
          .foregroundStyle(.tertiary)
          .frame(width: 60, alignment: .trailing)
      }
    }
  }

  // MARK: Incidents

  private var activeIncidents: [Incident] {
    controller.activeIncidents
  }

  private var incidentsSection: some View {
    sectionCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 8) {
          Image(systemName: "bell").font(.callout)
          Text("Active Incidents").font(.headline)
          Spacer()
          Button {
            openSection(.incidents)
          } label: {
            HStack(spacing: 3) {
              Text("See All")
              Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.callout)
            .foregroundStyle(Color.accentColor)
          }
          .buttonStyle(.plain)
        }
        if activeIncidents.isEmpty {
          Text("No active incidents")
            .font(.callout)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(activeIncidents.prefix(3).enumerated()), id: \.offset) { _, incident in
            incidentRow(incident)
          }
        }
      }
    }
  }

  private func incidentRow(_ incident: Incident) -> some View {
    let timeline = controller.evaluation?.timelines.first { $0.incident == incident }
    let processName = timeline?.relevantProcesses.first?.process.name ?? "System"
    return HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.red.opacity(0.15))
        .frame(width: 36, height: 36)
        .overlay(Image(systemName: "waveform.path.ecg").font(.callout).foregroundStyle(.red))
      VStack(alignment: .leading, spacing: 2) {
        Text(incidentTitle(incident, timeline: timeline)).font(.callout.bold())
        Text(processName).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Text(relativeTime(incident.startedAt))
        .font(.callout)
        .foregroundStyle(.secondary)
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }

  private func incidentTitle(_ incident: Incident, timeline: IncidentTimeline?) -> String {
    switch incident.source {
    case .rule:
      let metric = timeline?.metricSamples.first?.metric ?? "metric"
      return "High \(metric.uppercased()) Usage"
    case .baseline:
      return "Unusual behavior"
    }
  }

  private func relativeTime(_ date: Date) -> String {
    let seconds = Date().timeIntervalSince(date)
    if seconds < 60 {
      return "just now"
    }
    if seconds < 3600 {
      return "\(Int(seconds / 60))m ago"
    }
    if seconds < 86_400 {
      return "\(Int(seconds / 3600))h ago"
    }
    return "\(Int(seconds / 86_400))d ago"
  }

  // MARK: Monitoring mode

  private var modeSection: some View {
    sectionCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 8) {
          Image(systemName: "waveform.path").font(.callout)
          Text("Monitoring Mode").font(.headline)
        }
        HStack(spacing: 10) {
          modeCard(
            title: "Normal", caption: "Balanced for everyday use",
            active: currentMode == .normal, tint: .blue
          )
          modeCard(
            title: "Reduced", caption: "Lower overhead",
            active: currentMode == .reduced, tint: .gray
          )
          modeCard(
            title: "High Detail", caption: "More data for investigation",
            active: currentMode == .highDetail, tint: .orange
          )
        }
        HStack {
          Text("Auto reverts after 30 minutes")
            .font(.callout)
            .foregroundStyle(.secondary)
          Spacer()
          Button("Start for 30 Minutes") {
            controller.requestHighDetail(seconds: 1800)
          }
          .buttonStyle(.bordered)
          .font(.callout)
          .disabled(currentMode == .highDetail)
        }
      }
    }
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
      Circle().fill(active ? tint : Color.gray.opacity(0.4)).frame(width: 9, height: 9)
      VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.callout.bold())
        Text(caption).font(.caption2).foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(active ? tint.opacity(0.5) : Color.gray.opacity(0.15))
    )
  }

  // MARK: Actions

  private var actionRow: some View {
    HStack(spacing: 10) {
      actionButton(title: "Open App", icon: "square.grid.2x2") { openSection(.overview) }
      actionButton(title: "Process Viewer", icon: "list.bullet") { openSection(.processes) }
      actionButton(title: "System Health", icon: "waveform.path.ecg") {
        openSection(.incidents)
      }
    }
  }

  private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon).foregroundStyle(Color.accentColor)
        Text(title)
      }
      .font(.callout)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.15)))
    }
    .buttonStyle(.plain)
  }

  // MARK: Shared

  private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content()
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.12)))
  }

  private func percent(_ value: Double?) -> String {
    value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
  }

  private func rate(_ value: Double?) -> String {
    value.map(formatRate) ?? "–"
  }

  private func statusColor(_ headline: String) -> Color {
    switch headline {
    case "Reduced monitoring": return .orange
    case "High-detail investigation": return .blue
    default: return .green
    }
  }
}
