import AppKit
import MonitoringEngine
import SwiftUI

/// Incidents center (issues 01+02): header with status filter pills and a
/// date-range selector, plus the master-detail split — the incident list on
/// the left, the selected incident's detail on the right. Selection is the
/// only state held here; row content comes from the engine.
struct IncidentsView: View {
  @ObservedObject var controller: EngineController
  @State private var statusFilter: IncidentStatusFilter = .all
  @State private var dateRange: IncidentDateRange = .week
  @State private var selectedIncident: Incident?

  private var incidents: [Incident] {
    filteredIncidents(
      controller.evaluation?.incidents ?? [],
      status: statusFilter,
      range: dateRange,
      now: Date()
    )
  }

  private var effectiveSelection: Incident? {
    if let selected = selectedIncident, incidents.contains(selected) {
      return selected
    }
    return incidents.first
  }

  private func timeline(for incident: Incident) -> IncidentTimeline? {
    controller.evaluation?.timelines.first { $0.incident == incident }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header
      HStack(alignment: .top, spacing: 12) {
        incidentList
          .frame(width: 340)
        detailPane
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding()
  }

  // MARK: - Header (issue 01)

  private var header: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Incidents")
          .font(.largeTitle.bold())
        Text("Detected anomalies and notable system events.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 8) {
        HStack(spacing: 2) {
          ForEach(IncidentStatusFilter.allCases, id: \.self) { filter in
            Button {
              statusFilter = filter
            } label: {
              Text(filter.rawValue)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                  statusFilter == filter
                    ? Color(nsColor: .controlBackgroundColor) : Color.clear,
                  in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(statusFilter == filter ? .primary : .secondary)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        Menu {
          ForEach(IncidentDateRange.allCases, id: \.self) { range in
            Button(range.rawValue) { dateRange = range }
          }
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "calendar")
              .font(.callout)
            Text(dateRange.rawValue)
              .font(.callout)
            Image(systemName: "chevron.down")
              .font(.caption2)
          }
          .foregroundStyle(.primary)
          .padding(8)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
      }
    }
  }

  // MARK: - List (issue 02)

  private var incidentList: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        if incidents.isEmpty {
          Text("No incidents in this range.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
        } else {
          ForEach(incidents, id: \.self) { incident in
            incidentRow(incident)
          }
        }
      }
      .padding(4)
    }
    .dashboardCardStyle()
  }

  private func incidentRow(_ incident: Incident) -> some View {
    let timeline = timeline(for: incident)
    let metric = timeline?.metricSamples.first?.metric
    let category = incidentCategory(metric: metric)
    let isActive = incident.recoveredAt == nil
    let isSelected = effectiveSelection == incident
    return Button {
      selectedIncident = incident
    } label: {
      HStack(spacing: 10) {
        IncidentCategoryBadge(category: category)
        VStack(alignment: .leading, spacing: 2) {
          Text(incidentTitle(incident: incident, metric: metric))
            .font(.callout.bold())
            .lineLimit(1)
          Text(processSubtitle(for: timeline))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        IncidentStatusPill(isActive: isActive)
        Text(relativeTimeString(from: incident.startedAt, to: Date()))
          .font(.caption)
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(10)
      .background(
        isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
        in: RoundedRectangle(cornerRadius: 10)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(
            isSelected ? Color.accentColor.opacity(0.4) : Color.clear,
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      "\(incidentTitle(incident: incident, metric: metric)), \(isActive ? "active" : "resolved")"
    )
  }

  private func processSubtitle(for timeline: IncidentTimeline?) -> String {
    let names = timeline?.relevantProcesses.map(\.process.name) ?? []
    if names.isEmpty {
      return "System"
    }
    if names.count == 1 {
      return names[0]
    }
    return "\(names.count) processes"
  }

  // MARK: - Detail pane

  private var detailPane: some View {
    Group {
      if let selection = effectiveSelection {
        IncidentDetailView(controller: controller, incident: selection)
      } else {
        VStack(spacing: 8) {
          Image(systemName: "bell")
            .font(.largeTitle)
            .foregroundStyle(.tertiary)
          Text("Select an incident to see its details.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dashboardCardStyle()
      }
    }
  }
}
