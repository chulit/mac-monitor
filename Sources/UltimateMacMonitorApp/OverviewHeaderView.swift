import MonitoringEngine
import SwiftUI

/// Header of the Overview screen (overview issue 02): prominent title, live
/// monitoring status, time-range picker, and the Start/Stop Investigation
/// control bound to the engine's high-detail mode.
struct OverviewHeaderView: View {
  @ObservedObject var controller: EngineController
  @Binding var timeRange: OverviewTimeRange

  /// Matches the popover's 30-minute investigation session.
  private let investigationSeconds: TimeInterval = 1800

  private var isInvestigating: Bool {
    if case .highDetail = controller.evaluation?.observation?.mode {
      return true
    }
    return false
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center) {
        Text("Overview")
          .font(.largeTitle.bold())
        Spacer()
        timeRangeMenu
        investigationButton
      }
      statusRow
    }
  }

  // MARK: Status

  @ViewBuilder
  private var statusRow: some View {
    switch controller.evaluation?.observation?.mode {
    case .highDetail(let remaining, let limit, let warning):
      HStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
        VStack(alignment: .leading, spacing: 2) {
          Text("Investigating...")
            .font(.headline)
          Text(
            warning
              ? "Ending soon · \(Int(remaining.rounded()))s remaining"
              : "High-detail collection · \(Int(remaining.rounded()))s of \(Int(limit.rounded()))s"
          )
          .font(.callout)
          .foregroundStyle(.secondary)
        }
      }
    case .reduced(let reason, _):
      HStack(spacing: 8) {
        Circle().fill(.orange).frame(width: 10, height: 10)
        VStack(alignment: .leading, spacing: 2) {
          Text("Reduced monitoring")
            .font(.headline)
          Text(reason)
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    case .normal, nil:
      HStack(spacing: 8) {
        Circle().fill(.green).frame(width: 10, height: 10)
        VStack(alignment: .leading, spacing: 2) {
          Text("Monitoring Normal")
            .font(.headline)
          Text("All systems are running smoothly.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  // MARK: Controls

  private var timeRangeMenu: some View {
    Menu {
      ForEach(OverviewTimeRange.allCases, id: \.self) { range in
        Button(range.title) {
          timeRange = range
        }
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "calendar")
        Text(timeRange.title)
        Image(systemName: "chevron.down")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .font(.callout)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
      .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.gray.opacity(0.15)))
    }
    .menuStyle(.borderlessButton)
    .help("Data window for the overview charts.")
  }

  @ViewBuilder
  private var investigationButton: some View {
    if isInvestigating {
      Button {
        controller.endHighDetail()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "stop.fill")
          Text("Stop Investigation")
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.red)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.red.opacity(0.35)))
      }
      .buttonStyle(.plain)
    } else {
      Button {
        controller.requestHighDetail(seconds: investigationSeconds)
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "scope")
          Text("Start Investigation")
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.blue)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.blue.opacity(0.5)))
      }
      .buttonStyle(.plain)
    }
  }
}
