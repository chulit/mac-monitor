import MonitoringEngine
import SwiftUI

/// "Recent Incidents" card for the overview bottom row (issue 05): categorized
/// anomaly badges, titles, responsible processes, relative times, and a
/// "See All" link into the Incidents section. Narrow inputs keep it an
/// independent invalidation boundary.
struct RecentIncidentsCard: View {
  let incidents: [Incident]
  let timelines: [IncidentTimeline]
  let onSeeAll: () -> Void
  let onSelectIncident: (Incident) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Recent Incidents")
          .font(.headline)
        Spacer()
        Button(action: onSeeAll) {
          HStack(spacing: 2) {
            Text("See All")
            Image(systemName: "chevron.right")
          }
          .font(.callout)
          .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
      }
      if incidents.isEmpty {
        Text("No incidents recorded")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 120)
      } else {
        ForEach(incidents.prefix(4), id: \.self) { incident in
          incidentRow(incident)
        }
      }
    }
    .dashboardCardStyle()
  }

  private func incidentRow(_ incident: Incident) -> some View {
    let timeline = timelines.first { $0.incident == incident }
    let metric = timeline?.metricSamples.first?.metric
    let category = incidentCategory(metric: metric)
    return Button { onSelectIncident(incident) } label: {
      HStack(spacing: 10) {
        RoundedRectangle(cornerRadius: 8)
          .fill(badgeTint(category).opacity(0.15))
          .frame(width: 36, height: 36)
          .overlay(
            Image(systemName: badgeIcon(category))
              .font(.callout)
              .foregroundStyle(badgeTint(category))
              .accessibilityHidden(true)
          )
        VStack(alignment: .leading, spacing: 2) {
          Text(incidentTitle(incident: incident, metric: metric))
            .font(.callout.bold())
          Text(timeline?.relevantProcesses.first?.process.name ?? "System")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(relativeTimeString(from: incident.startedAt, to: Date()))
          .font(.callout)
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
    }
    .buttonStyle(.plain)
  }

  private func badgeIcon(_ category: IncidentCategory) -> String {
    switch category {
    case .cpu: return "flame.fill"
    case .memory: return "leaf.fill"
    case .disk: return "internaldrive.fill"
    case .network: return "waveform.path.ecg"
    case .unknown: return "exclamationmark.triangle.fill"
    }
  }

  private func badgeTint(_ category: IncidentCategory) -> Color {
    switch category {
    case .cpu: return .orange
    case .memory: return .purple
    case .disk: return .green
    case .network: return .blue
    case .unknown: return .gray
    }
  }
}
