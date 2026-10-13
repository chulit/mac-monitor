import AppKit
import MonitoringEngine
import SwiftUI

/// Processes screen (issues 01+02): header with search/sort/live badge,
/// three summary cards, and the process table with tree toggle. Row data
/// comes from `processTableEntries`; only query/sort/tree/selection state
/// lives here.
struct ProcessesView: View {
  @ObservedObject var controller: EngineController
  @State private var query = ""
  @State private var sort: ProcessSort = .cpu
  @State private var showTree = false
  @State private var expanded: Set<String> = []
  @State private var lastUpdate = Date()
  @State private var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      VStack(alignment: .leading, spacing: 16) {
        header
        summaryCards
        processTableCard
      }
      .padding()
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(for: Process.self) { process in
        ProcessDetailView(controller: controller, process: process) { selected in
          path.append(selected)
        }
      }
    }
    .onChange(of: controller.processes.count) { _ in
      lastUpdate = Date()
    }
  }

  private var entries: [ProcessTableEntry] {
    processTableEntries(
      samples: controller.processes,
      query: query,
      sort: sort,
      showTree: showTree,
      expanded: expanded
    )
  }

  private var totalCount: Int {
    Set(controller.processes.map(\.process.id)).count
  }

  // MARK: - Header (issue 01)

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Processes")
          .font(.largeTitle.bold())
        Text("Monitor resource usage and process relationships.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Search processes", text: $query)
            .textFieldStyle(.plain)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .frame(width: 220)
        Menu {
          ForEach(ProcessSort.allCases, id: \.self) { option in
            Button(option.label) { sort = option }
          }
        } label: {
          HStack(spacing: 6) {
            Text(sort.label)
            Image(systemName: "chevron.up.chevron.down")
              .font(.caption)
          }
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        HStack(spacing: 6) {
          Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
          Text("Live")
            .font(.callout)
          Image(systemName: "arrow.clockwise")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Live updates on")
      }
    }
  }

  private var summaryCards: some View {
    let cpu = controller.cpuHistory.last?.value
    let memoryFraction = controller.memoryHistory.last?.value
    let memoryGB = memoryFraction.map {
      $0 * Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000
    }
    return HStack(spacing: 12) {
      MetricStatCard(
        title: "Total Processes",
        icon: "cpu",
        tint: .gray,
        valueText: "\(totalCount)",
        history: []
      )
      MetricStatCard(
        title: "CPU Usage",
        icon: "cpu",
        tint: .blue,
        valueText: cpu.map { String(format: "%.0f%%", $0 * 100) } ?? "—",
        history: controller.cpuHistory
      )
      MetricStatCard(
        title: "Memory",
        icon: "memorychip",
        tint: .purple,
        valueText: memoryGB.map { String(format: "%.1f GB", $0) } ?? "—",
        history: controller.memoryHistory
      )
    }
  }

  // MARK: - Table (issue 02)

  private var processTableCard: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        Text("Show Process Tree")
          .font(.callout)
          .foregroundStyle(.secondary)
        Toggle("", isOn: $showTree)
          .toggleStyle(.switch)
          .labelsHidden()
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      columnHeaders
      Divider()
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(entries, id: \.process.id) { entry in
            processRow(entry)
            Divider()
          }
        }
      }
      .frame(maxHeight: .infinity)
      Divider()
      Text("\(totalCount) processes · Updated \(relativeTimeString(from: lastUpdate, to: Date()))")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    .dashboardCardStyle()
  }

  private var columnHeaders: some View {
    HStack(spacing: 0) {
      Text("Process")
        .frame(maxWidth: .infinity, alignment: .leading)
      Text("PID")
        .frame(width: 64, alignment: .trailing)
      Text("CPU")
        .frame(width: 150, alignment: .leading)
      Text("Memory")
        .frame(width: 80, alignment: .trailing)
      Text("Parent Process")
        .frame(maxWidth: .infinity, alignment: .leading)
      Color.clear
        .frame(width: 36)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal)
    .padding(.vertical, 6)
    .background(Color.secondary.opacity(0.06))
  }

  private func processRow(_ entry: ProcessTableEntry) -> some View {
    HStack(spacing: 0) {
      HStack(spacing: 8) {
        Group {
          if entry.hasChildren {
            Image(systemName: entry.isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption)
              .foregroundStyle(.secondary)
              .highPriorityGesture(
                TapGesture().onEnded { toggleExpanded(entry) }
              )
          } else {
            Color.clear
          }
        }
        .frame(width: 12)
        ProcessAppIcon(process: entry.process)
          .frame(width: 28, height: 28)
        Text(entry.process.name)
          .font(.callout)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, CGFloat(entry.depth) * 20)
      Text(entry.process.id)
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 64, alignment: .trailing)
      HStack(spacing: 8) {
        Text(String(format: "%.1f%%", entry.cpuShare * 100))
          .font(.callout.monospacedDigit())
          .frame(width: 52, alignment: .trailing)
        SlimProgressBar(value: entry.cpuShare, tint: .blue)
      }
      .frame(width: 150, alignment: .leading)
      // Per-process memory is not collected by the engine: an honest dash,
      // never a fabricated figure.
      Text("—")
        .font(.callout)
        .foregroundStyle(.tertiary)
        .frame(width: 80, alignment: .trailing)
      Text(entry.parentName ?? "—")
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
      Menu {
        Button("Open Details") { openDetails(entry) }
        Button("Copy PID") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(entry.process.id, forType: .string)
        }
        Button("Copy Process Name") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(entry.process.name, forType: .string)
        }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
          .frame(width: 36, height: 28)
          .contentShape(Rectangle())
      }
      .menuStyle(.borderlessButton)
    }
    .padding(.horizontal)
    .padding(.vertical, 6)
    .contentShape(Rectangle())
    .onTapGesture { openDetails(entry) }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(entry.process.name), PID \(entry.process.id), \(Int((entry.cpuShare * 100).rounded())) percent CPU"
    )
    .accessibilityAddTraits(.isButton)
  }

  private func toggleExpanded(_ entry: ProcessTableEntry) {
    if expanded.contains(entry.process.id) {
      expanded.remove(entry.process.id)
    } else {
      expanded.insert(entry.process.id)
    }
  }

  private func openDetails(_ entry: ProcessTableEntry) {
    path.append(entry.process)
  }
}

private extension ProcessSort {
  var label: String {
    switch self {
    case .cpu: return "CPU"
    case .name: return "Name"
    case .pid: return "PID"
    }
  }
}
