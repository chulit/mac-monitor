import MonitoringEngine
import SwiftUI

/// Dedicated investigation progress card (overview issue 06), shown only
/// while a high-detail session runs: a blue donut gauge with the live session
/// fraction, and a 3-step vertical diagnostic phase tracker. Narrow `let`
/// input keeps it an independent invalidation boundary.
struct InvestigationProgressCard: View {
  let progress: InvestigationProgress

  var body: some View {
    HStack(alignment: .center, spacing: 24) {
      donut
      phaseTracker
    }
    .dashboardCardStyle()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilitySummary)
  }

  private var accessibilitySummary: String {
    let percent = Int((progress.fraction * 100).rounded())
    return
      "Investigating, \(percent) percent complete, \(progress.completedCount) of 3 phases complete"
  }

  private var donut: some View {
    let percent = Int((progress.fraction * 100).rounded())
    return ZStack {
      Circle()
        .stroke(Color.blue.opacity(0.15), lineWidth: 12)
      Circle()
        .trim(from: 0, to: progress.fraction)
        .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
        .rotationEffect(.degrees(-90))
      VStack(spacing: 2) {
        Text("\(percent)%")
          .font(.title2.bold().monospacedDigit())
        Text("Investigating")
          .font(.caption.bold())
        Text("\(progress.completedCount) of 3 phases")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .frame(width: 140, height: 140)
  }

  private var phaseTracker: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(progress.phases, id: \.title) { phase in
        phaseRow(phase, isLast: phase.title == progress.phases.last?.title)
      }
    }
  }

  private func phaseRow(_ phase: InvestigationPhase, isLast: Bool) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(spacing: 4) {
        phaseIcon(phase.state)
        if !isLast {
          Rectangle()
            .fill(Color.gray.opacity(0.25))
            .frame(width: 2, height: 32)
        }
      }
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text(phase.title)
              .font(.callout.bold())
            Text(phase.subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          Text(phase.statusText)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(minWidth: 72, alignment: .trailing)
          Text(phase.durationText)
            .font(.callout.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(minWidth: 48, alignment: .trailing)
        }
        if let barProgress = phase.progress {
          SlimProgressBar(value: barProgress, tint: .blue)
        }
      }
      .padding(.vertical, 3)
    }
  }

  private func phaseIcon(_ state: InvestigationPhase.State) -> some View {
    Group {
      switch state {
      case .completed:
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
      case .active:
        Image(systemName: "target")
          .foregroundStyle(.blue)
      case .pending:
        Circle()
          .stroke(Color.gray.opacity(0.4), lineWidth: 2)
          .frame(width: 22, height: 22)
      }
    }
    .font(.title2)
    .frame(width: 28, height: 28)
    .accessibilityHidden(true)
  }
}
