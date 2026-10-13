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
        appIcon(for: item.process)
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
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue.opacity(0.15))
              RoundedRectangle(cornerRadius: 3)
                .fill(Color.blue)
                .frame(width: geometry.size.width * CGFloat(item.share))
            }
          }
          .frame(height: 6)
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

  /// The real app icon via the running application; a generic glyph when the
  /// process is gone or has no UI representation.
  private func appIcon(for process: Process) -> Image {
    if let pid = Int32(process.id),
      let icon = NSRunningApplication(processIdentifier: pid)?.icon
    {
      return Image(nsImage: icon)
    }
    return Image(systemName: "app.fill")
  }
}
