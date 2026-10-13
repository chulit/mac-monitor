import AppKit
import MonitoringEngine
import SwiftUI

/// Right detail pane of the Incidents screen (issues 03–06): header with
/// summary stats, the metric timeline chart, the related-processes
/// attribution table, and the event trail. All values come from the
/// incident's own timeline; missing data renders "—".
struct IncidentDetailView: View {
  @ObservedObject var controller: EngineController
  let incident: Incident

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  private var timeline: IncidentTimeline? {
    controller.evaluation?.timelines.first { $0.incident == incident }
  }

  private var metric: String? {
    timeline?.metricSamples.first?.metric
  }

  private var category: IncidentCategory {
    incidentCategory(metric: metric)
  }

  private var title: String {
    incidentTitle(incident: incident, metric: metric)
  }

  private var isActive: Bool {
    incident.recoveredAt == nil
  }

  private var primaryProcess: String {
    let names = timeline?.relevantProcesses.map(\.process.name) ?? []
    if names.isEmpty {
      return "System"
    }
    if names.count == 1 {
      return names[0]
    }
    return "\(names.count) processes"
  }

  private var timingLine: String {
    let when = Self.dateFormatter.string(from: incident.startedAt)
    if isActive {
      let elapsed = formatDuration(Date().timeIntervalSince(incident.startedAt))
      return "\(when) • Ongoing for \(elapsed)"
    }
    if let recoveredAt = incident.recoveredAt {
      return "\(when) • Resolved \(relativeTimeString(from: recoveredAt, to: Date()))"
    }
    return when
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        headerSection
        summarySection
        if let timeline {
          IncidentTimelineChart(timeline: timeline, incident: incident)
        }
        relatedProcessesSection
        eventTrailSection
      }
      .padding()
    }
    .dashboardCardStyle()
  }

  // MARK: - Header (issue 03)

  private var headerSection: some View {
    HStack(spacing: 12) {
      IncidentCategoryBadge(category: category, size: 44)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.title3.bold())
        Text(primaryProcess)
          .font(.callout)
          .foregroundStyle(.secondary)
        Text(timingLine)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      IncidentStatusPill(isActive: isActive)
      Menu {
        Button("Copy Summary") {
          copyToClipboard(summaryText)
        }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
      }
      .menuStyle(.borderlessButton)
    }
  }

  private var summaryText: String {
    let summary = incidentSummary(incident: incident, timeline: timeline)
    let peak = summary.peak.map { String(format: "%.0f%%", $0 * 100) } ?? "—"
    return "\(title) — \(primaryProcess) — Peak \(peak) — \(timingLine)"
  }

  private var summarySection: some View {
    let summary = incidentSummary(incident: incident, timeline: timeline)
    let metricLabel = metric.map {
      ["cpu": "CPU", "memory": "Memory", "disk": "Disk", "network": "Network", "temperature": "Temperature"][$0] ?? $0.capitalized
    } ?? "Metric"
    let duration: String
    if isActive {
      duration = "Ongoing"
    } else if let recoveredAt = incident.recoveredAt {
      duration = formatDuration(recoveredAt.timeIntervalSince(incident.startedAt))
    } else {
      duration = "—"
    }
    return VStack(alignment: .leading, spacing: 8) {
      Text("Summary")
        .font(.headline)
      HStack(spacing: 0) {
        summaryStat(
          label: "Peak \(metricLabel)",
          value: summary.peak.map { formatStatValue($0) } ?? "—"
        )
        summaryStat(
          label: "Average \(metricLabel)",
          value: summary.average.map { formatStatValue($0) } ?? "—"
        )
        summaryStat(label: "Duration", value: duration)
        summaryStat(label: "Affected Processes", value: "\(summary.affectedProcesses)")
      }
    }
  }

  private func formatStatValue(_ value: Double) -> String {
    if let metric, ["cpu", "memory", "disk"].contains(metric) {
      return String(format: "%.0f%%", value * 100)
    }
    return String(format: "%.1f", value)
  }

  private func summaryStat(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.bold().monospacedDigit())
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }

  // MARK: - Related processes (issue 05)

  private var relatedProcessesSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Related Processes")
        .font(.headline)
      let processes = timeline?.relevantProcesses ?? []
      if processes.isEmpty {
        Text("No process attribution was recorded for this incident.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        relatedHeader
        let ceiling = processes.map(\.contribution).max() ?? 1
        ForEach(processes, id: \.process.id) { relevance in
          relatedRow(relevance, ceiling: ceiling)
          Divider()
        }
        Text("Attribution shows measured correlation during the incident span, not causation.")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .dashboardCardStyle()
  }

  private var relatedHeader: some View {
    HStack(spacing: 0) {
      Text("Process")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("CPU")
        .frame(width: 150, alignment: .leading)
      Text("Memory")
        .frame(width: 80, alignment: .trailing)
      Text("Parent Process")
        .frame(maxWidth: .infinity, alignment: .leading)
      Color.clear.frame(width: 36)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.vertical, 4)
  }

  private func relatedRow(_ relevance: ProcessRelevance, ceiling: Double) -> some View {
    let share = relevance.contribution / max(ceiling, 1e-9)
    return HStack(spacing: 0) {
      HStack(spacing: 8) {
        ProcessAppIcon(process: relevance.process)
          .frame(width: 28, height: 28)
        Text(relevance.process.name)
          .font(.callout)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 8) {
        Text(String(format: "%.1f%%", relevance.contribution * 100))
          .font(.callout.monospacedDigit())
          .frame(width: 52, alignment: .trailing)
        SlimProgressBar(value: share, tint: .red)
      }
      .frame(width: 150, alignment: .leading)
      // Per-process memory is not collected: an honest dash.
      Text("—")
        .font(.callout)
        .foregroundStyle(.tertiary)
        .frame(width: 80, alignment: .trailing)
      Text(parentName(for: relevance.process) ?? "—")
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Menu {
        Button("Copy PID") { copyToClipboard(relevance.process.id) }
        Button("Copy Process Name") { copyToClipboard(relevance.process.name) }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
          .frame(width: 36, height: 28)
          .contentShape(Rectangle())
      }
      .menuStyle(.borderlessButton)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(relevance.process.name), \(Int((relevance.contribution * 100).rounded())) percent contribution"
    )
  }

  private func parentName(for process: Process) -> String? {
    guard let parentId = process.parent else {
      return nil
    }
    return controller.processes.first { $0.process.id == parentId }?.process.name
  }

  // MARK: - Event trail (issue 06)

  private var eventTrailSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Timeline")
        .font(.headline)
      let events = incidentEvents(incident: incident, timeline: timeline, now: Date())
      ForEach(Array(events.enumerated()), id: \.element) { index, event in
        HStack(alignment: .top, spacing: 10) {
          VStack(spacing: 0) {
            Circle()
              .fill(eventTint(event.kind))
              .frame(width: 8, height: 8)
              .padding(.top, 4)
            if index < events.count - 1 {
              Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 2, height: 22)
            }
          }
          Text(Self.timeFormatter.string(from: event.timestamp))
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 44, alignment: .leading)
          Text(event.text)
            .font(.callout)
            .foregroundStyle(event.kind == .ongoing ? .secondary : .primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
          "\(Self.timeFormatter.string(from: event.timestamp)): \(event.text)"
        )
      }
    }
    .dashboardCardStyle()
  }

  private func eventTint(_ kind: IncidentEvent.Kind) -> Color {
    switch kind {
    case .detected: return .red
    case .peak: return .orange
    case .note: return .blue
    case .recovered: return .green
    case .ongoing: return .gray
    }
  }

  private func copyToClipboard(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
  }
}

/// Colored category badge shared by the incident list and detail header.
struct IncidentCategoryBadge: View {
  let category: IncidentCategory
  var size: CGFloat = 36

  var body: some View {
    Image(systemName: icon)
      .font(.system(size: size * 0.45))
      .foregroundStyle(tint)
      .frame(width: size, height: size)
      .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.25))
      .accessibilityHidden(true)
  }

  private var icon: String {
    switch category {
    case .cpu: return "flame.fill"
    case .memory: return "exclamationmark.triangle.fill"
    case .disk: return "internaldrive.fill"
    case .network: return "waveform.path.ecg"
    case .unknown: return "exclamationmark.circle.fill"
    }
  }

  private var tint: Color {
    switch category {
    case .cpu: return .red
    case .memory: return .orange
    case .disk: return .gray
    case .network: return .blue
    case .unknown: return .gray
    }
  }
}

/// Status pill shared by the incident list and detail header.
struct IncidentStatusPill: View {
  let isActive: Bool

  var body: some View {
    Text(isActive ? "Active" : "Resolved")
      .font(.caption.bold())
      .foregroundStyle(isActive ? Color.red : Color.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(
        (isActive ? Color.red : Color.gray).opacity(0.12),
        in: RoundedRectangle(cornerRadius: 8)
      )
      .accessibilityLabel(isActive ? "Active incident" : "Resolved incident")
  }
}
