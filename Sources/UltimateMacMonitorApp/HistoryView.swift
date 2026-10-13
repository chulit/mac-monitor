import AppKit
import MonitoringEngine
import SwiftUI

enum HistoryViewMode: String, CaseIterable {
  case table
  case grid
}

/// History screen (issues 01+02): header with date range and search, the
/// multi-day System Activity chart, and the filterable Incident History
/// table. Rows navigate to the history detail view.
struct HistoryView: View {
  @ObservedObject var controller: EngineController
  @State private var range: HistoryRange = .week
  @State private var query = ""
  @State private var metric = "cpu"
  @State private var severity: SeverityFilter = .all
  @State private var sort: HistorySort = .newest
  @State private var viewMode: HistoryViewMode = .table
  @State private var path = NavigationPath()

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, HH:mm"
    return formatter
  }()

  private var snapshot: HistorySnapshot? {
    controller.historySnapshot()
  }

  private var items: [HistoricalIncident] {
    filterHistoricalIncidents(
      historicalIncidents(
        incidents: snapshot?.incidents ?? [],
        details: snapshot?.details ?? [],
        now: Date()
      ),
      severity: severity,
      query: query,
      sort: sort
    )
  }

  private var series: [ActivityPoint] {
    activitySeries(
      details: snapshot?.details ?? [],
      summaries: snapshot?.summaries ?? [],
      metric: metric,
      range: range,
      now: Date()
    )
  }

  private let activityMetrics: [(key: String, label: String, icon: String, tint: Color)] = [
    ("cpu", "CPU", "cpu", .blue),
    ("memory", "Memory", "memorychip", .purple),
    ("disk", "Disk", "internaldrive", .green),
    ("network", "Network", "network", .orange),
    ("temperature", "Temperature", "thermometer.medium", .red),
  ]

  var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(alignment: .leading, spacing: 12) {
          header
          activityCard
          incidentHistoryCard
        }
        .padding()
      }
      .navigationDestination(for: Incident.self) { incident in
        HistoryDetailView(controller: controller, incident: incident) {
          path.removeLast()
        }
        .toolbar(.hidden, for: .navigationBar)
      }
      .toolbar(.hidden, for: .navigationBar)
    }
  }

  // MARK: - Header (issue 01)

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text("History")
          .font(.largeTitle.bold())
        Text("View system activity, incidents, and resource usage over time.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        Menu {
          ForEach(HistoryRange.allCases, id: \.self) { value in
            Button(value.rawValue) { range = value }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "calendar")
            Text(range.rawValue)
            Image(systemName: "chevron.down")
              .font(.caption2)
          }
          .font(.callout)
          .foregroundStyle(.primary)
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        HStack(spacing: 6) {
          Image(systemName: "magnifyingglass")
            .foregroundStyle(.secondary)
          TextField("Search history...", text: $query)
            .textFieldStyle(.plain)
        }
        .font(.callout)
        .padding(8)
        .frame(width: 220)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  // MARK: - System activity (issue 01)

  private var activityCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("System Activity")
          .font(.headline)
        Spacer()
        HStack(spacing: 4) {
          ForEach(activityMetrics, id: \.key) { entry in
            Button {
              metric = entry.key
            } label: {
              HStack(spacing: 4) {
                Image(systemName: entry.icon)
                  .font(.caption)
                Text(entry.label)
                  .font(.callout)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(
                metric == entry.key ? entry.tint.opacity(0.12) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
              )
              .foregroundStyle(metric == entry.key ? entry.tint : .secondary)
            }
            .buttonStyle(.plain)
          }
        }
      }
      HistoryActivityChart(points: series, metric: metric, range: range)
    }
    .dashboardCardStyle()
  }

  // MARK: - Incident history (issue 02)

  private var incidentHistoryCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Incident History")
          .font(.headline)
        HStack(spacing: 2) {
          ForEach(SeverityFilter.allCases, id: \.self) { filter in
            Button {
              severity = filter
            } label: {
              Text(filter.rawValue)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                  severity == filter ? Color(nsColor: .controlBackgroundColor) : Color.clear,
                  in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(severity == filter ? .primary : .secondary)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        Spacer()
        Menu {
          ForEach(HistorySort.allCases, id: \.self) { value in
            Button(value.rawValue) { sort = value }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
            Text(sort.rawValue)
            Image(systemName: "chevron.down")
              .font(.caption2)
          }
          .font(.callout)
          .foregroundStyle(.primary)
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        HStack(spacing: 2) {
          viewModeButton(.table, icon: "list.bullet")
          viewModeButton(.grid, icon: "square.grid.2x2")
        }
        .padding(3)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
      }
      if items.isEmpty {
        Text("No incidents match these filters.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
      } else if viewMode == .table {
        historyTable
      } else {
        historyGrid
      }
    }
    .dashboardCardStyle()
  }

  private func viewModeButton(_ mode: HistoryViewMode, icon: String) -> some View {
    Button {
      viewMode = mode
    } label: {
      Image(systemName: icon)
        .font(.callout)
        .foregroundStyle(viewMode == mode ? .white : .secondary)
        .padding(6)
        .background(
          viewMode == mode ? Color.accentColor : Color.clear,
          in: RoundedRectangle(cornerRadius: 6)
        )
    }
    .buttonStyle(.plain)
  }

  private var historyTable: some View {
    VStack(spacing: 0) {
      tableHeader
      ForEach(items, id: \.incident) { item in
        Button {
          path.append(item.incident)
        } label: {
          tableRow(item)
        }
        .buttonStyle(.plain)
        Divider()
      }
    }
  }

  private var tableHeader: some View {
    HStack(spacing: 0) {
      Text("Time").frame(width: 110, alignment: .leading)
      Text("Type").frame(width: 52, alignment: .leading)
      Text("Title").frame(maxWidth: .infinity, alignment: .leading)
      Text("Affected Processes").frame(width: 140, alignment: .leading)
      Text("Peak Value").frame(width: 90, alignment: .trailing)
      Text("Duration").frame(width: 80, alignment: .trailing)
      Text("Status").frame(width: 90, alignment: .trailing)
      Color.clear.frame(width: 24)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.vertical, 6)
  }

  private func tableRow(_ item: HistoricalIncident) -> some View {
    let incident = item.incident
    let isActive = incident.recoveredAt == nil
    return HStack(spacing: 0) {
      Text(Self.timeFormatter.string(from: incident.startedAt))
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 110, alignment: .leading)
      IncidentCategoryBadge(category: item.category, size: 30)
        .frame(width: 52, alignment: .leading)
      Text(item.title)
        .font(.callout)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lineLimit(1)
      Text(affectedProcessesText(for: incident))
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 140, alignment: .leading)
        .lineLimit(1)
      Text(peakText(for: item))
        .font(.callout.monospacedDigit())
        .frame(width: 90, alignment: .trailing)
      Text(durationText(for: incident))
        .font(.callout)
        .foregroundStyle(.secondary)
        .frame(width: 80, alignment: .trailing)
      IncidentStatusPill(isActive: isActive)
        .frame(width: 90, alignment: .trailing)
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundStyle(.tertiary)
        .frame(width: 24, alignment: .trailing)
    }
    .padding(.vertical, 8)
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(item.title), \(isActive ? "active" : "resolved")")
  }

  private var historyGrid: some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 8)],
      spacing: 8
    ) {
      ForEach(items, id: \.incident) { item in
        Button {
          path.append(item.incident)
        } label: {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              IncidentCategoryBadge(category: item.category, size: 30)
              Spacer()
              IncidentStatusPill(isActive: item.incident.recoveredAt == nil)
            }
            Text(item.title)
              .font(.callout.bold())
              .lineLimit(1)
            Text(Self.timeFormatter.string(from: item.incident.startedAt))
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(peakText(for: item))
              .font(.callout.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          .padding(12)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Formatting helpers

  private func affectedProcessesText(for incident: Incident) -> String {
    if let timeline = controller.evaluation?.timelines.first(where: { $0.incident == incident }) {
      let names = timeline.relevantProcesses.map(\.process.name)
      if names.isEmpty {
        return "System"
      }
      if names.count == 1 {
        return names[0]
      }
      return "\(names.count) processes"
    }
    return "—"
  }

  private func peakText(for item: HistoricalIncident) -> String {
    guard let peak = item.peak, let metric = item.metric else {
      return "—"
    }
    switch metric {
    case "cpu":
      return "CPU \(String(format: "%.0f%%", peak * 100))"
    case "memory":
      let gb = peak * Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
      return "RAM \(String(format: "%.1f GB", gb))"
    case "disk":
      return "Disk \(String(format: "%.0f%%", peak * 100))"
    default:
      return String(format: "%.1f", peak)
    }
  }

  private func durationText(for incident: Incident) -> String {
    if incident.recoveredAt == nil {
      return "Ongoing"
    }
    guard let recoveredAt = incident.recoveredAt else {
      return "—"
    }
    return formatDuration(recoveredAt.timeIntervalSince(incident.startedAt))
  }
}
