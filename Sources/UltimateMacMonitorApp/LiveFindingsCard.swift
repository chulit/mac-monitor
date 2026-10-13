import MonitoringEngine
import SwiftUI

/// "Live Findings" card for the investigation (issue 07): a real-time stream
/// of detected conditions with severity icons and relative timestamps.
/// Narrow input keeps it an independent invalidation boundary.
struct LiveFindingsCard: View {
  let findings: [LiveFinding]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "waveform.path.ecg")
          .foregroundStyle(.blue)
          .accessibilityHidden(true)
        Text("Live Findings")
          .font(.headline)
      }
      if findings.isEmpty {
        Text("No findings yet — the investigation is collecting data.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 100)
      } else {
        ForEach(findings, id: \.self) { finding in
          findingRow(finding)
        }
      }
    }
    .dashboardCardStyle()
  }

  private func findingRow(_ finding: LiveFinding) -> some View {
    let relative = relativeTimeString(from: finding.startedAt, to: Date())
    return HStack(spacing: 10) {
      Image(systemName: findingIcon(finding.category))
        .font(.callout)
        .foregroundStyle(findingTint(finding.category))
        .frame(width: 28, height: 28)
        .background(findingTint(finding.category).opacity(0.12), in: Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(finding.title)
          .font(.callout)
        Text(finding.processName)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Text(relative)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(finding.title), \(finding.processName), \(relative)")
  }

  private func findingIcon(_ category: IncidentCategory) -> String {
    switch category {
    case .cpu: return "flame.fill"
    case .memory: return "exclamationmark.triangle.fill"
    case .disk: return "internaldrive.fill"
    case .network: return "waveform.path.ecg"
    case .unknown: return "circle.fill"
    }
  }

  private func findingTint(_ category: IncidentCategory) -> Color {
    switch category {
    case .cpu: return .red
    case .memory: return .orange
    case .disk: return .gray
    case .network: return .blue
    case .unknown: return .gray
    }
  }
}
