import SwiftUI
import MonitoringEngine

/// Condensed status for the menu-bar popover: headline numbers, status,
/// and a way into the full window.
struct PopoverView: View {
  @ObservedObject var controller: EngineController
  var onOpen: () -> Void
  var onQuit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 16) {
        VStack(alignment: .leading) {
          Text("CPU")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
          Text(percent(controller.cpuShare))
            .font(.title.bold().monospacedDigit())
        }
        VStack(alignment: .leading) {
          Text("Memory")
            .font(.caption.bold())
            .foregroundStyle(.secondary)
          Text(percent(controller.memoryHistory.last?.value))
            .font(.title.bold().monospacedDigit())
        }
        Spacer()
      }
      if let evaluation = controller.evaluation {
        let snapshot = makeDashboard(evaluation)
        Text(snapshot.headline)
          .font(.callout)
        Text(snapshot.monitoring.headline)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text("Collecting first samples…")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      HStack {
        Button("Open Monitor", action: onOpen)
          .buttonStyle(.link)
        Spacer()
        Button("Quit", action: onQuit)
          .buttonStyle(.link)
      }
      .font(.callout)
    }
    .padding(14)
    .frame(width: 300)
  }

  private func percent(_ value: Double?) -> String {
    value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
  }
}
