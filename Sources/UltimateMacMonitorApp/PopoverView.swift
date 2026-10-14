import SwiftUI
import MonitoringEngine

/// Menu-bar popover following the dark-mode design: header, 2x2 metric
/// cards, temperature card, system details, active incidents, monitoring
/// mode, and action buttons. Cards show live data where collectors exist
/// and honest "–" states where they don't (per-cluster CPU and GPU
/// sensors do not exist on this model).
struct PopoverView: View {
  @ObservedObject var controller: EngineController
  var openSection: (AppSection) -> Void
  var onOpenSettings: () -> Void
  var onQuit: () -> Void

  @State private var detailsExpanded = true

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      cardsGrid
      temperatureCard
      systemDetails
      incidentsSection
      modeSection
      actionRow
    }
    .padding(16)
    .frame(width: 400)
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 12) {
      AppLogo(size: 44)
      VStack(alignment: .leading, spacing: 3) {
        Text("Ultimate Mac Monitor").font(.headline)
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
      Menu {
        Button("Settings…") { onOpenSettings() }
        Divider()
        Button("Quit Ultimate Mac Monitor", role: .destructive) { onQuit() }
      } label: {
        Image(systemName: "ellipsis")
          .font(.body)
          .foregroundStyle(.primary)
          .frame(width: 36, height: 36)
          .background(.thinMaterial, in: Circle())
          .overlay(Circle().stroke(Color.gray.opacity(0.15)))
      }
      .accessibilityLabel("More options")
    }
  }

  // MARK: Metric cards

  private var cardsGrid: some View {
    LazyVGrid(
      columns: [GridItem(.flexible()), GridItem(.flexible())],
      spacing: 10
    ) {
      metricCard(
        title: "CPU", icon: "cpu", tint: .blue,
        value: percent(controller.cpuShare), history: controller.cpuHistory
      )
      metricCard(
        title: "Memory", icon: "memorychip", tint: .purple,
        value: percent(controller.memoryHistory.last?.value),
        history: controller.memoryHistory
      )
      metricCard(
        title: "Disk", icon: "internaldrive", tint: .green,
        value: percent(controller.diskHistory.last?.value), history: controller.diskHistory
      )
      metricCard(
        title: "Network", icon: "arrow.up.arrow.down", tint: .blue,
        value: rate(controller.networkHistory.last?.value),
        history: controller.networkHistory
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

  private var temperatureCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "thermometer")
          .font(.caption)
          .foregroundStyle(.orange)
          .frame(width: 24, height: 24)
          .background(Color.orange.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
        Text("Temperature").font(.caption).foregroundStyle(.secondary)
      }
      HStack(spacing: 12) {
        Text(temperatureValue).font(.title.bold().monospacedDigit())
        Sparkline(values: controller.temperatureHistory, tint: .orange)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
  }

  private var temperatureValue: String {
    guard controller.temperatureFresh, let last = controller.temperatureHistory.last else {
      return "–"
    }
    return "\(Int(last.value.rounded()))°C"
  }

  // MARK: System details

  private var systemDetails: some View {
    sectionCard {
      VStack(alignment: .leading, spacing: 12) {
        Button {
          detailsExpanded.toggle()
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "thermometer").font(.callout).foregroundStyle(.orange)
            Text("System Details").font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
              .rotationEffect(.degrees(detailsExpanded ? 90 : 0))
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("System Details")
        if detailsExpanded {
          detailRow(
            label: "CPU (Average)",
            value: controller.temperatureHistory.last?.value,
            tint: .orange, unit: "°C"
          )
          detailRow(
            label: "CPU (Performance)", value: nil, tint: .blue, unit: "%"
          )
          detailRow(
            label: "CPU (Efficiency)", value: nil, tint: .cyan, unit: "%"
          )
          detailRow(label: "GPU", value: nil, tint: .purple, unit: "%")
          detailRow(
            label: "SSD",
            value: controller.temperatureStorageHistory.last?.value,
            tint: .orange, unit: "°C"
          )
        }
      }
    }
  }

  private func detailRow(label: String, value: Double?, tint: Color, unit: String) -> some View {
    HStack(spacing: 12) {
      Text(label)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 140, alignment: .leading)
      if let value {
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.gray.opacity(0.18))
            Capsule()
              .fill(tint)
              .frame(width: geometry.size.width * min(max(value / 100, 0), 1))
          }
        }
        .frame(height: 10)
        Text("\(Int(value.rounded()))\(unit)")
          .font(.callout.monospacedDigit())
          .frame(width: 60, alignment: .trailing)
      } else {
        Spacer()
        Text("–")
          .font(.callout)
          .foregroundStyle(.tertiary)
          .frame(width: 60, alignment: .trailing)
          .accessibilityLabel("\(label) unavailable on this Mac")
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
          HStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
              .font(.title)
              .foregroundStyle(.green)
              .frame(width: 44, height: 44)
              .background(Color.green.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
              Text("No active incidents").font(.callout.bold())
              Text("Your Mac is running smoothly.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
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
        Text(incidentTitle(incident: incident, metric: timeline?.metricSamples.first?.metric))
          .font(.callout.bold())
        Text(processName).font(.caption).foregroundStyle(.secondary)
      }
      Spacer()
      Text(relativeTimeString(from: incident.startedAt, to: Date()))
        .font(.callout)
        .foregroundStyle(.secondary)
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
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
            title: "Normal", caption: "Balanced use",
            active: currentMode == .normal, tint: .blue
          ) {
            controller.settings.setMonitoringMode(.normal)
          }
          modeCard(
            title: "Reduced", caption: "Lower overhead",
            active: currentMode == .reduced, tint: .gray
          ) {
            controller.settings.setMonitoringMode(.reduced)
          }
          modeCard(
            title: "High Detail", caption: "More data",
            active: currentMode == .highDetail, tint: .orange
          ) {
            controller.requestHighDetail(seconds: 1800)
          }
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

  private func modeCard(
    title: String,
    caption: String,
    active: Bool,
    tint: Color,
    select: @escaping () -> Void
  ) -> some View {
    Button(action: select) {
      HStack(spacing: 8) {
        ZStack {
          Circle()
            .stroke(active ? tint : Color.gray.opacity(0.4), lineWidth: 2)
            .frame(width: 16, height: 16)
          if active {
            Circle().fill(tint).frame(width: 8, height: 8)
          }
        }
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
    .buttonStyle(.plain)
    .accessibilityLabel("\(title) monitoring mode")
  }

  // MARK: Actions

  private var actionRow: some View {
    HStack(spacing: 10) {
      actionButton(title: "Open App", subtitle: "Launch the full app", icon: "square.grid.2x2") {
        openSection(.overview)
      }
      actionButton(
        title: "Process Viewer", subtitle: "Monitor processes", icon: "list.bullet"
      ) {
        openSection(.processes)
      }
      actionButton(
        title: "System Health", subtitle: "Detailed diagnostics", icon: "waveform.path.ecg"
      ) {
        openSection(.incidents)
      }
    }
  }

  private func actionButton(
    title: String,
    subtitle: String,
    icon: String,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(Color.accentColor)
          .frame(width: 28)
        VStack(alignment: .leading, spacing: 1) {
          Text(title).font(.callout.bold())
          Text(subtitle).font(.caption2).foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
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
