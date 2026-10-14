import AppKit
import MonitoringEngine
import SwiftUI
import UniformTypeIdentifiers

/// History detail screen (issues 03–05): back navigation, header, overview,
/// metric timeline with the shaded incident period, affected processes,
/// primary process details, system context, and actions. Every value comes
/// from recorded history; anything the retention store never kept renders
/// "—" or an explicit empty state.
struct HistoryDetailView: View {
  @ObservedObject var controller: EngineController
  let incident: Incident
  let onBack: () -> Void

  @State private var showExclusionAlert = false
  @State private var shareError: String?

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private var snapshot: HistorySnapshot? {
    controller.historySnapshot()
  }

  private var item: HistoricalIncident? {
    historicalIncidents(
      incidents: [incident],
      details: snapshot?.details ?? [],
      now: Date()
    ).first
  }

  private var timeline: IncidentTimeline {
    historicalTimeline(incident: incident, details: snapshot?.details ?? [], now: Date())
  }

  private var liveTimeline: IncidentTimeline? {
    controller.evaluation?.timelines.first { $0.incident == incident }
  }

  private var metric: String? {
    item?.metric
  }

  private var metricLabel: String {
    switch metric {
    case "cpu": return "CPU"
    case "memory": return "Memory"
    case "disk": return "Disk"
    case "network": return "Network"
    default: return "Metric"
    }
  }

  private var isActive: Bool {
    incident.recoveredAt == nil
  }

  private var timingLine: String {
    let when = Self.dateFormatter.string(from: incident.startedAt)
    if isActive {
      return "\(when) • Ongoing for \(formatDuration(Date().timeIntervalSince(incident.startedAt)))"
    }
    if let recoveredAt = incident.recoveredAt {
      let lasted = formatDuration(recoveredAt.timeIntervalSince(incident.startedAt))
      return "\(when) • Lasted \(lasted)"
    }
    return when
  }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          backButton
          headerSection
          HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
              overviewCard
              affectedProcessesCard
                .id("affectedProcesses")
              systemContextCard
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 12) {
              timelineCard
              processDetailsCard
              actionsCard(proxy: proxy)
            }
            .frame(maxWidth: .infinity)
          }
        }
        .padding()
      }
    }
    .alert("Create Exclusion", isPresented: $showExclusionAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Process exclusions are not implemented yet.")
    }
    .alert("Share Incident", isPresented: Binding(
      get: { shareError != nil },
      set: { if !$0 { shareError = nil } }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(shareError ?? "Export failed.")
    }
  }

  // MARK: - Header (issue 03)

  private var backButton: some View {
    Button(action: onBack) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left")
          .font(.callout)
        Text("Back to History")
          .font(.callout)
      }
      .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
  }

  private var headerSection: some View {
    HStack(spacing: 12) {
      IncidentCategoryBadge(category: item?.category ?? .unknown, size: 44)
      VStack(alignment: .leading, spacing: 2) {
        Text(item?.title ?? "Incident")
          .font(.title3.bold())
        Text(timingLine)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      IncidentStatusPill(isActive: isActive)
    }
  }

  // MARK: - Overview (issue 03)

  private var overviewCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Overview")
        .font(.headline)
      Text("Brief summary of this incident.")
        .font(.caption)
        .foregroundStyle(.secondary)
      overviewRow(icon: "calendar", label: "Time", value: Self.dateFormatter.string(from: incident.startedAt))
      overviewRow(icon: "clock", label: "Duration", value: durationText)
      overviewRow(icon: "waveform.path.ecg", label: "Peak \(metricLabel)", value: peakText)
      overviewRow(
        icon: "list.bullet",
        label: "Affected Processes",
        value: affectedProcessesSummary
      )
      HStack(spacing: 12) {
        Label("Status", systemImage: "info.circle")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(width: 140, alignment: .leading)
        IncidentStatusPill(isActive: isActive)
      }
      VStack(alignment: .leading, spacing: 4) {
        Label("Description", systemImage: "text.alignleft")
          .font(.callout)
          .foregroundStyle(.secondary)
        if let item {
          Text(incidentNarrative(item: item, now: Date()))
            .font(.callout)
        } else {
          Text("—")
            .font(.callout)
            .foregroundStyle(.tertiary)
        }
      }
    }
    .dashboardCardStyle()
  }

  private func overviewRow(icon: String, label: String, value: String) -> some View {
    HStack(spacing: 12) {
      Label(label, systemImage: icon)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 140, alignment: .leading)
      Text(value)
        .font(.callout)
    }
  }

  private var durationText: String {
    if isActive {
      return "Ongoing"
    }
    guard let recoveredAt = incident.recoveredAt else {
      return "—"
    }
    return formatDuration(recoveredAt.timeIntervalSince(incident.startedAt))
  }

  private var peakText: String {
    guard let peak = item?.peak else {
      return "—"
    }
    switch metric {
    case "cpu", "disk":
      return String(format: "%.0f%%", peak * 100)
    case "memory":
      let gb = peak * Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
      return String(format: "%.1f GB (%.0f%%)", gb, peak * 100)
    default:
      return String(format: "%.1f", peak)
    }
  }

  private var affectedProcessesSummary: String {
    guard let processes = liveTimeline?.relevantProcesses else {
      return "Unknown (not recorded)"
    }
    if processes.isEmpty {
      return "System"
    }
    let primary = processes[0].process.name
    return processes.count == 1 ? "\(primary) (primary)" : "\(primary) (primary), +\(processes.count - 1) more"
  }

  // MARK: - Timeline (issue 04)

  private var timelineCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("\(metricLabel) Usage Timeline")
        .font(.headline)
      Text("\(metricLabel) usage around the time of this incident.")
        .font(.caption)
        .foregroundStyle(.secondary)
      IncidentTimelineChart(timeline: timeline, incident: incident)
      HStack(spacing: 16) {
        HStack(spacing: 6) {
          Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
          Text("\(metricLabel) Usage")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        HStack(spacing: 6) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.red.opacity(0.2))
            .frame(width: 12, height: 8)
          Text("Incident Period")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .dashboardCardStyle()
  }

  // MARK: - Affected processes (issue 05)

  private var affectedProcessesCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Affected Processes")
        .font(.headline)
      Text("Processes that contributed to this incident.")
        .font(.caption)
        .foregroundStyle(.secondary)
      if let processes = liveTimeline?.relevantProcesses, !processes.isEmpty {
        let ceiling = processes.map(\.contribution).max() ?? 1
        ForEach(processes, id: \.process.id) { relevance in
          HStack(spacing: 8) {
            ProcessAppIcon(process: relevance.process)
              .frame(width: 28, height: 28)
            Text(relevance.process.name)
              .font(.callout)
              .lineLimit(1)
            Spacer()
            Text(String(format: "%.1f%%", relevance.contribution * 100))
              .font(.callout.monospacedDigit())
            SlimProgressBar(
              value: relevance.contribution / max(ceiling, 1e-9),
              tint: .red
            )
            .frame(width: 80)
          }
          .padding(.vertical, 4)
          Divider()
        }
        Text("Shares are measured correlation during the incident span, not causation.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      } else {
        Text("Process attribution is only recorded for recent incidents.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
    .dashboardCardStyle()
  }

  // MARK: - Process details (issue 04)

  private var processDetailsCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Process Details")
        .font(.headline)
      if let process = liveTimeline?.relevantProcesses.first?.process {
        HStack(spacing: 10) {
          ProcessAppIcon(process: process)
            .frame(width: 40, height: 40)
          VStack(alignment: .leading, spacing: 2) {
            Text(process.name)
              .font(.callout.bold())
            Text("Primary contributing process")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button("Open in Activity Monitor ↗") {
            NSWorkspace.shared.open(URL(
              fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"
            ))
          }
          .buttonStyle(.link)
          .font(.callout)
        }
        detailRow(label: "Process ID", value: process.id)
        detailRow(
          label: "Parent Process",
          value: parentName(for: process) ?? "—"
        )
        // Path, memory, and start time are not collected by the engine.
        detailRow(label: "Path", value: "—")
        detailRow(label: "Memory Usage", value: "—")
        detailRow(label: "Start Time", value: "—")
      } else {
        Text("Process details are only available while the incident is recent.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
    .dashboardCardStyle()
  }

  private func detailRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Text(value)
        .font(.callout.monospacedDigit())
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.vertical, 2)
  }

  private func parentName(for process: Process) -> String? {
    guard let parentId = process.parent else {
      return nil
    }
    return controller.processes.first { $0.process.id == parentId }?.process.name
  }

  // MARK: - System context (issue 05)

  private var systemContextCard: some View {
    let context = systemContext(incident: incident, details: snapshot?.details ?? [])
    return VStack(alignment: .leading, spacing: 8) {
      Text("System Context")
        .font(.headline)
      Text("System conditions when this incident occurred.")
        .font(.caption)
        .foregroundStyle(.secondary)
      contextRow(
        icon: "memorychip",
        tint: .purple,
        label: "Memory Usage",
        value: memoryText(context.memoryFraction)
      )
      contextRow(
        icon: "internaldrive",
        tint: .green,
        label: "Disk Activity",
        value: context.diskFraction.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
      )
      contextRow(
        icon: "wifi",
        tint: .blue,
        label: "Network Activity",
        value: context.networkRate.map { formatRate($0) } ?? "—"
      )
    }
    .dashboardCardStyle()
  }

  private func memoryText(_ fraction: Double?) -> String {
    guard let fraction else {
      return "—"
    }
    let gb = fraction * Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
    return String(format: "%.1f GB (%.0f%%)", gb, fraction * 100)
  }

  private func formatRate(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond >= 1_000_000 {
      return String(format: "%.0f MB/s", bytesPerSecond / 1_000_000)
    }
    if bytesPerSecond >= 1_000 {
      return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
    }
    return String(format: "%.0f B/s", bytesPerSecond)
  }

  private func contextRow(icon: String, tint: Color, label: String, value: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .foregroundStyle(tint)
        .frame(width: 24)
      Text(label)
        .font(.callout)
      Spacer()
      Text(value)
        .font(.callout.monospacedDigit())
        .foregroundStyle(value == "—" ? .tertiary : .primary)
    }
    .padding(.vertical, 2)
  }

  // MARK: - Actions (issue 05)

  private func actionsCard(proxy: ScrollViewProxy) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Actions")
        .font(.headline)
      Text("What you can do next.")
        .font(.caption)
        .foregroundStyle(.secondary)
      HStack(spacing: 8) {
        Button {
          if controller.settings.settings.reduceMotion {
            proxy.scrollTo("affectedProcesses", anchor: .top)
          } else {
            withAnimation {
              proxy.scrollTo("affectedProcesses", anchor: .top)
            }
          }
        } label: {
          Label("View Related Processes", systemImage: "list.bullet")
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        Button {
          showExclusionAlert = true
        } label: {
          Label("Create Exclusion", systemImage: "nosign")
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        Button {
          shareIncident()
        } label: {
          Label("Share Incident", systemImage: "square.and.arrow.up")
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
      }
    }
    .dashboardCardStyle()
  }

  private func shareIncident() {
    guard let snapshot else {
      shareError = "No recorded history to export."
      return
    }
    do {
      let package = try IncidentArchive().export(
        timeline,
        summaries: snapshot.summaries,
        redactProcessNames: controller.hidesSensitiveInfo,
        now: Date()
      )
      let data = try package.encoded()
      let panel = NSSavePanel()
      panel.allowedContentTypes = [.json]
      panel.nameFieldStringValue =
        "incident-\(Int(incident.startedAt.timeIntervalSince1970)).json"
      panel.begin { response in
        guard response == .OK, let url = panel.url else {
          return
        }
        do {
          try data.write(to: url)
        } catch {
          shareError = "Could not write the export file."
        }
      }
    } catch {
      shareError = "Could not build the incident package."
    }
  }
}
