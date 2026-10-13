import MonitoringEngine
import SwiftUI

/// One metric card of the overview row (overview issue 03): chip icon badge,
/// large readout, baseline delta badge while investigating, and a smooth
/// cubic-bezier sparkline with a color-matched vertical gradient fill.
struct MetricStatCard: View {
  var title: String
  var icon: String
  var tint: Color
  var valueText: String
  var history: [(date: Date, value: Double)]
  /// Relative baseline deviation while investigating; nil hides the badge.
  var delta: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.callout)
          .foregroundStyle(tint)
          .frame(width: 28, height: 28)
          .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
        Text(title)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(valueText)
          .font(.title2.bold().monospacedDigit())
        if let delta {
          Text(String(format: "%@ %+.0f%% from baseline", delta >= 0 ? "↑" : "↓", delta * 100))
            .font(.caption2.bold())
            .foregroundStyle(.red)
        }
      }
      Sparkline(values: history, tint: tint)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15)))
    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
  }
}
