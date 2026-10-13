import AppKit
import MonitoringEngine
import SwiftUI

/// "Top Processes" card for the overview bottom row (issue 05): real app
/// icons, names, locale-aware percentage readouts, proportional blue progress
/// bars, and a CPU/Memory sort menu. Rows navigate to the Processes section.
struct TopProcessesCard: View {
  let samples: [ProcessSample]
  let onSelectProcess: () -> Void

  @State private var sortMetric = "cpu"

  private static let percentFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 1
    return formatter
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Top Processes")
          .font(.headline)
        Spacer()
        Menu {
          Picker("Sort by", selection: $sortMetric) {
            Text("by CPU").tag("cpu")
            Text("by Memory").tag("memory")
          }
        } label: {
          Label(
            sortMetric == "cpu" ? "by CPU" : "by Memory",
            systemImage: "arrow.up.arrow.down"
          )
          .font(.callout)
        }
      }
      let top = topProcesses(samples: samples, metric: sortMetric, limit: 5)
      if top.isEmpty {
        Text("No process data")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 120)
      } else {
        ForEach(top, id: \.process.id) { item in
          processRow(item)
        }
      }
    }
    .dashboardCardStyle()
  }

  private func processRow(_ item: TopProcess) -> some View {
    Button(action: onSelectProcess) {
      HStack(spacing: 10) {
        ProcessAppIcon(process: item.process)
          .frame(width: 28, height: 28)
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(item.process.name)
              .font(.callout)
              .lineLimit(1)
            Spacer()
            Text(Self.percentFormatter.string(from: NSNumber(value: item.share)) ?? "–")
              .font(.callout.monospacedDigit())
              .foregroundStyle(.secondary)
          }
          SlimProgressBar(value: item.share, tint: .blue)
        }
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .accessibilityHidden(true)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(item.process.name), \(Int((item.share * 100).rounded())) percent")
  }

}
