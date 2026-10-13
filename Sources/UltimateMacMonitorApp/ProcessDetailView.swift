import AppKit
import MonitoringEngine
import SwiftUI

/// Process detail screen (issues 03–06): header with identity and actions,
/// sub-navigation tabs, live metric cards, historical charts, metadata,
/// resource details, control actions, and related processes. Every value
/// shown is real; anything the engine does not collect renders "—".
struct ProcessDetailView: View {
  @ObservedObject var controller: EngineController
  let process: Process
  let onSelectProcess: (Process) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var tab: DetailTab = .overview
  @State private var cpuHistory: [(date: Date, value: Double)] = []
  @State private var metadata: ProcessMetadata?
  @State private var showFirstConfirm = false
  @State private var showFinalConfirm = false
  @State private var terminateMessage: String?
  @State private var showExclusionAlert = false

  enum DetailTab: String, CaseIterable {
    case overview = "Overview"
    case performance = "Performance"
    case threads = "Threads"
    case files = "Files & Connections"
    case incidents = "Incidents"

    var icon: String {
      switch self {
      case .overview: return "square.grid.2x2"
      case .performance: return "chart.line.uptrend.xyaxis"
      case .threads: return "point.3.connected.trianglepath.dotted"
      case .files: return "folder"
      case .incidents: return "bell"
      }
    }
  }

  private static let launchFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private var currentShare: Double? {
    controller.processes.first {
      $0.process.id == process.id && $0.metric == "cpu"
    }?.value
  }

  private var isRunning: Bool {
    currentShare != nil
  }

  private var children: [Process] {
    var seen = Set<String>()
    return controller.processes.compactMap { sample in
      guard sample.process.parent == process.id,
        seen.insert(sample.process.id).inserted
      else {
        return nil
      }
      return sample.process
    }
  }

  private var processIncidents: [IncidentTimeline] {
    (controller.evaluation?.timelines ?? []).filter { timeline in
      timeline.relevantProcesses.contains { $0.process.id == process.id }
    }
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        backButton
        headerSection
        tabBar
        switch tab {
        case .overview:
          metricCards
          chartsRow
          infoGrid
        case .performance:
          metricCards
          chartsRow
        case .incidents:
          incidentsSection
        case .threads:
          emptyTab(
            icon: "point.3.connected.trianglepath.dotted",
            message: "Per-thread inspection is not collected by the engine yet."
          )
        case .files:
          emptyTab(
            icon: "folder",
            message: "Open files and network connections are not collected by the engine yet."
          )
        }
      }
      .padding()
    }
    .toolbar(.hidden, for: .navigationBar)
    .onAppear {
      metadata = ProcessMetadata.resolve(process: process)
    }
    .onChange(of: controller.processes) { _ in
      if let share = currentShare {
        cpuHistory.append((date: Date(), value: share))
        cpuHistory = Array(cpuHistory.suffix(600))
      }
    }
    .alert("Terminate Process?", isPresented: $showFirstConfirm) {
      Button("Cancel", role: .cancel) {}
      Button("Continue") { showFinalConfirm = true }
    } message: {
      Text(
        "Terminate \(process.name) (PID \(process.id))? Confirm this is the process you mean — the identity check runs before anything happens."
      )
    }
    .alert("Final Confirmation", isPresented: $showFinalConfirm) {
      Button("Cancel", role: .cancel) {}
      Button("Terminate", role: .destructive) { executeTermination() }
    } message: {
      Text("This cannot be undone. \(process.name) will be stopped immediately.")
    }
    .alert("Termination", isPresented: Binding(
      get: { terminateMessage != nil },
      set: { if !$0 { terminateMessage = nil } }
    )) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(terminateMessage ?? "")
    }
    .alert("Create Exclusion", isPresented: $showExclusionAlert) {
      Button("OK", role: .cancel) {}
    } message: {
      Text("Process exclusions are not implemented yet.")
    }
  }

  // MARK: - Header (issue 03)

  private var backButton: some View {
    Button {
      dismiss()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left")
          .font(.callout)
        Text("Back to Processes")
          .font(.callout)
      }
      .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
  }

  private var headerSection: some View {
    HStack(spacing: 12) {
      ProcessAppIcon(process: process)
        .frame(width: 56, height: 56)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(process.name)
            .font(.title2.bold())
            .lineLimit(1)
          HStack(spacing: 4) {
            Circle()
              .fill(isRunning ? Color.green : Color.gray)
              .frame(width: 8, height: 8)
            Text(isRunning ? "Running" : "Exited")
              .font(.caption.bold())
              .foregroundStyle(isRunning ? Color.green : Color.secondary)
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            (isRunning ? Color.green : Color.gray).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 8)
          )
          .accessibilityLabel(isRunning ? "Running" : "Exited")
        }
        Text(headerSubtitle)
          .font(.callout)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      Menu {
        Button("Copy PID") { copyToClipboard(process.id) }
        if let bundleID = metadata?.bundleID {
          Button("Copy Bundle ID") { copyToClipboard(bundleID) }
        }
        if let path = metadata?.executablePath {
          Button("Copy Executable Path") { copyToClipboard(path) }
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.callout)
          .foregroundStyle(.secondary)
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
      }
      .menuStyle(.borderlessButton)
      if metadata?.executablePath != nil {
        Button {
          revealInFinder()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "folder.fill")
              .foregroundStyle(.blue)
            Text("Open in Finder")
              .font(.callout)
          }
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var headerSubtitle: String {
    let bundle = metadata?.bundleID ?? "—"
    let version = metadata.map { $0.version.map { "v\($0)" } ?? "v—" } ?? "v—"
    let launched: String
    if let date = metadata?.launchDate {
      launched = "Launched \(Self.launchFormatter.string(from: date))"
    } else {
      launched = "Launch time unknown"
    }
    return "\(bundle) · \(version) · \(launched)"
  }

  private var tabBar: some View {
    HStack(spacing: 4) {
      ForEach(DetailTab.allCases, id: \.self) { item in
        Button {
          tab = item
        } label: {
          HStack(spacing: 6) {
            Image(systemName: item.icon)
              .font(.caption)
            Text(item.rawValue)
              .font(.callout)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            tab == item ? Color.blue.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
          )
          .foregroundStyle(tab == item ? Color.blue : Color.secondary)
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Metric cards (issue 03)

  private var metricCards: some View {
    HStack(spacing: 12) {
      MetricStatCard(
        title: "CPU Usage",
        icon: "cpu",
        tint: .blue,
        valueText: currentShare.map { String(format: "%.1f%%", $0 * 100) } ?? "—",
        history: cpuHistory
      )
      // The engine collects no per-process memory/disk/network figures:
      // honest dashes, never fabricated numbers.
      MetricStatCard(
        title: "Memory Usage",
        icon: "memorychip",
        tint: .purple,
        valueText: "—",
        history: []
      )
      MetricStatCard(
        title: "Disk Activity",
        icon: "internaldrive",
        tint: .green,
        valueText: "—",
        history: []
      )
      MetricStatCard(
        title: "Network Activity",
        icon: "wifi",
        tint: .orange,
        valueText: "—",
        history: []
      )
    }
  }

  // MARK: - Charts (issue 04)

  private var chartsRow: some View {
    HStack(alignment: .top, spacing: 12) {
      ProcessHistoryChart(
        title: "CPU Usage",
        points: cpuHistory,
        tint: .blue,
        yLabels: ["100%", "75%", "50%", "25%", "0%"],
        emptyMessage: "No CPU history yet — it builds while this view is open."
      )
      ProcessHistoryChart(
        title: "Memory Usage",
        points: [],
        tint: .purple,
        yLabels: ["4 GB", "3 GB", "2 GB", "1 GB", "0"],
        emptyMessage: "Per-process memory history is not collected by the engine."
      )
    }
  }

  // MARK: - Info grid (issues 05+06)

  private var infoGrid: some View {
    HStack(alignment: .top, spacing: 12) {
      processInformationCard
      resourceUsageCard
      VStack(spacing: 12) {
        actionsCard
        relatedProcessesCard
      }
    }
  }

  private var processInformationCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Process Information")
        .font(.headline)
      infoRow(icon: "doc", label: "Process Name", value: process.name)
      infoRow(icon: "cube", label: "Bundle ID", value: metadata?.bundleID ?? "—")
      infoRow(icon: "info.circle", label: "Version", value: metadata?.version ?? "—")
      infoRow(icon: "person", label: "Developer", value: "—")
      infoRow(
        icon: "clock",
        label: "Launch Time",
        value: metadata?.launchDate.map { Self.launchFormatter.string(from: $0) } ?? "—"
      )
      infoRow(icon: "number", label: "Process ID (PID)", value: process.id)
      infoRow(
        icon: "arrow.triangle.branch",
        label: "Parent Process",
        value: parentDescription
      )
      infoRow(
        icon: "doc.plaintext",
        label: "Executable Path",
        value: metadata?.executablePath ?? "—"
      )
    }
    .dashboardCardStyle()
  }

  private var parentDescription: String {
    guard let parentId = process.parent else {
      return "—"
    }
    let name = controller.processes.first { $0.process.id == parentId }?.process.name
    if let name {
      return "\(name) (PID \(parentId))"
    }
    return "PID \(parentId)"
  }

  private var resourceUsageCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Resource Usage Details")
        .font(.headline)
      infoRow(
        icon: "cpu",
        label: "CPU Usage",
        value: currentShare.map { String(format: "%.1f%%", $0 * 100) } ?? "—"
      )
      infoRow(icon: "clock", label: "CPU Time", value: "—")
      infoRow(icon: "point.3.connected.trianglepath.dotted", label: "Threads", value: "—")
      infoRow(icon: "memorychip", label: "Memory (RSS)", value: "—")
      infoRow(icon: "memorychip", label: "Memory (Virtual)", value: "—")
      infoRow(icon: "doc", label: "Open Files", value: "—")
      infoRow(icon: "arrow.down", label: "Network Read", value: "—")
      infoRow(icon: "arrow.up", label: "Network Write", value: "—")
      infoRow(icon: "internaldrive", label: "Disk Read", value: "—")
      infoRow(icon: "internaldrive", label: "Disk Write", value: "—")
      Text("Per-process telemetry beyond CPU is not collected by the engine yet.")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .dashboardCardStyle()
  }

  private func infoRow(icon: String, label: String, value: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .foregroundStyle(.secondary)
        .frame(width: 20)
        .accessibilityHidden(true)
      Text(label)
        .foregroundStyle(.secondary)
      Spacer()
      Text(value)
        .multilineTextAlignment(.trailing)
        .lineLimit(2)
    }
    .font(.callout)
    .accessibilityElement(children: .combine)
  }

  // MARK: - Actions (issue 06)

  private var actionsCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Actions")
        .font(.headline)
      actionButton(icon: "tv", title: "Show in Activity Monitor", showsDisclosure: true) {
        openActivityMonitor()
      }
      actionButton(icon: "folder", title: "Open Containing Folder", showsDisclosure: true) {
        revealInFinder()
      }
      .disabled(metadata?.executablePath == nil)
      actionButton(icon: "nosign", title: "Create Exclusion", showsDisclosure: false) {
        showExclusionAlert = true
      }
      Button {
        showFirstConfirm = true
      } label: {
        HStack {
          Image(systemName: "stop.circle.fill")
          Text("Terminate Process")
            .font(.callout.bold())
          Spacer()
        }
        .foregroundStyle(.red)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
      .disabled(!isRunning)
    }
    .dashboardCardStyle()
  }

  private func actionButton(
    icon: String,
    title: String,
    showsDisclosure: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .foregroundStyle(.secondary)
          .frame(width: 20)
          .accessibilityHidden(true)
        Text(title)
          .font(.callout)
        Spacer()
        if showsDisclosure {
          Image(systemName: "arrow.up.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
    .buttonStyle(.plain)
  }

  private var relatedProcessesCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Related Processes")
        .font(.headline)
      if children.isEmpty {
        Text("No child processes.")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(children, id: \.id) { child in
          Button {
            onSelectProcess(child)
          } label: {
            HStack(spacing: 8) {
              ProcessAppIcon(process: child)
                .frame(width: 24, height: 24)
              Text(child.name)
                .font(.callout)
                .lineLimit(1)
              Spacer()
              Text(child.id)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(child.name), PID \(child.id)")
        }
      }
    }
    .dashboardCardStyle()
  }

  private var incidentsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      if processIncidents.isEmpty {
        emptyTab(
          icon: "bell",
          message: "No incidents involving this process have been recorded."
        )
      } else {
        ForEach(processIncidents, id: \.incident) { timeline in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(incidentTitle(
                incident: timeline.incident,
                metric: timeline.metricSamples.first?.metric
              ))
              .font(.callout.bold())
              Text(relativeTimeString(from: timeline.incident.startedAt, to: Date()))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }
          .padding(10)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
      }
    }
    .dashboardCardStyle()
  }

  private func emptyTab(icon: String, message: String) -> some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.largeTitle)
        .foregroundStyle(.tertiary)
      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
    .dashboardCardStyle()
  }

  // MARK: - Actions

  private func executeTermination() {
    guard let identity = controller.processIdentity(for: process),
      let pid = Int(process.id)
    else {
      terminateMessage = "Cannot verify process identity — termination aborted."
      return
    }
    let control = ProcessControl(executor: DarwinProcessExecutor())
    let target = ControlledProcess(
      pid: pid,
      identityToken: identity.token,
      name: process.name
    )
    switch control.terminate(target, confirmations: 2) {
    case .exited:
      terminateMessage = "\(process.name) (PID \(process.id)) was terminated."
    case .confirmationRequired:
      terminateMessage = "Termination requires confirmation."
    case .identityChanged:
      terminateMessage =
        "Aborted: PID \(process.id) no longer refers to \(process.name) (PID reuse detected)."
    case .refused(let refusal):
      terminateMessage = refusal.explanation
    }
  }

  private func openActivityMonitor() {
    if let url = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: "com.apple.ActivityMonitor"
    ) {
      NSWorkspace.shared.openApplication(
        at: url,
        configuration: NSWorkspace.OpenConfiguration(),
        completionHandler: nil
      )
    }
  }

  private func revealInFinder() {
    guard let path = metadata?.executablePath else {
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
  }

  private func copyToClipboard(_ string: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
  }
}
