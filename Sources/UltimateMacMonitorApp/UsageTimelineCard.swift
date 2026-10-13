import MonitoringEngine
import SwiftUI

/// Full-width usage timeline card for the overview (issue 04): active metric
/// title, segmented pill tabs, and the interactive plot. It receives only the
/// histories and the selected range — narrow inputs per the SwiftUI skills —
/// and owns just the selected metric tab.
struct UsageTimelineCard: View {
  let histories: [TimelineMetric: [(date: Date, value: Double)]]
  let timeRange: OverviewTimeRange

  @State private var selectedMetric: TimelineMetric = .cpu

  private var tint: Color {
    switch selectedMetric {
    case .cpu: .blue
    case .memory: .purple
    case .disk: .green
    case .network: .cyan
    }
  }

  var body: some View {
    let now = Date()
    let filtered = samples(
      in: timeRange, endingAt: now, from: histories[selectedMetric] ?? []
    )
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(selectedMetric.title)
          .font(.headline)
        Spacer()
        Picker("Metric", selection: $selectedMetric) {
          ForEach(TimelineMetric.allCases, id: \.self) { metric in
            Text(metric.pillTitle).tag(metric)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 280)
      }
      if filtered.count >= 2 {
        TimelinePlot(
          samples: filtered,
          windowStart: now.addingTimeInterval(-timeRange.seconds),
          windowEnd: now,
          metric: selectedMetric,
          tint: tint,
          rangeLabel: timeRange.label
        )
      } else {
        Text("Collecting data…")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 220)
      }
    }
    .dashboardCardStyle()
  }
}
