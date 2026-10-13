import MonitoringEngine
import SwiftUI

/// "Preliminary Insights" card for the investigation (issue 07): synthesized
/// summaries built from the engine's own graded explanations, plus the
/// in-progress info banner. Narrow input keeps it an independent
/// invalidation boundary.
struct PreliminaryInsightsCard: View {
  let insights: [PreliminaryInsight]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "lightbulb.fill")
          .foregroundStyle(.blue)
          .accessibilityHidden(true)
        Text("Preliminary Insights")
          .font(.headline)
      }
      if insights.isEmpty {
        Text("Insights will appear as the investigation collects evidence.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 100)
      } else {
        ForEach(insights, id: \.self) { insight in
          insightBlock(insight)
        }
      }
      HStack(spacing: 8) {
        Image(systemName: "info.circle")
          .foregroundStyle(.blue)
          .accessibilityHidden(true)
        Text("Investigation is still in progress. Final report will be available shortly.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
    .dashboardCardStyle()
  }

  private func insightBlock(_ insight: PreliminaryInsight) -> some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: badgeIcon(insight.category))
        .font(.title3)
        .foregroundStyle(badgeTint(insight.category))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(insight.title)
          .font(.callout.bold())
        Text(insight.headline)
          .font(.callout)
        if !insight.detail.isEmpty {
          Text(insight.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(badgeTint(insight.category).opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    .accessibilityElement(children: .combine)
  }

  private func badgeIcon(_ category: IncidentCategory) -> String {
    switch category {
    case .cpu: return "exclamationmark.triangle.fill"
    case .memory: return "exclamationmark.triangle.fill"
    case .disk: return "internaldrive.fill"
    case .network: return "waveform.path.ecg"
    case .unknown: return "info.circle.fill"
    }
  }

  private func badgeTint(_ category: IncidentCategory) -> Color {
    switch category {
    case .cpu: return .red
    case .memory: return .orange
    case .disk: return .gray
    case .network: return .blue
    case .unknown: return .gray
    }
  }
}
