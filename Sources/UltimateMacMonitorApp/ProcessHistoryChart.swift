import MonitoringEngine
import SwiftUI

/// Historical chart for one per-process metric (issue 04): y-axis labels,
/// gridlines, smooth bezier curve with gradient fill, x-axis timestamps,
/// and a time-range selector. Empty data renders an honest empty state —
/// the engine collects no per-process memory/disk/network series.
struct ProcessHistoryChart: View {
  let title: String
  let points: [(date: Date, value: Double)]
  let tint: Color
  let yLabels: [String]
  let emptyMessage: String

  @State private var range: HistoryRange = .tenMinutes

  enum HistoryRange: String, CaseIterable {
    case oneMinute = "Last 1 Minute"
    case fiveMinutes = "Last 5 Minutes"
    case tenMinutes = "Last 10 Minutes"

    var seconds: TimeInterval {
      switch self {
      case .oneMinute: return 60
      case .fiveMinutes: return 300
      case .tenMinutes: return 600
      }
    }
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  private let yLabelWidth: CGFloat = 44
  private let xLabelHeight: CGFloat = 18

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title)
          .font(.headline)
        Spacer()
        Menu {
          ForEach(HistoryRange.allCases, id: \.self) { option in
            Button(option.rawValue) { range = option }
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.caption)
            Text(range.rawValue)
              .font(.callout)
            Image(systemName: "chevron.down")
              .font(.caption2)
          }
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
      }
      let visible = visiblePoints
      if visible.count >= 2 {
        chart(points: visible)
          .frame(height: 170)
      } else {
        Text(emptyMessage)
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 170, alignment: .center)
      }
    }
    .dashboardCardStyle()
  }

  private var visiblePoints: [(date: Date, value: Double)] {
    guard let end = points.last?.date else {
      return []
    }
    let start = end.addingTimeInterval(-range.seconds)
    return points.filter { $0.date >= start }
  }

  private func chart(points: [(date: Date, value: Double)]) -> some View {
    GeometryReader { geometry in
      let plotWidth = geometry.size.width - yLabelWidth
      let plotHeight = geometry.size.height - xLabelHeight
      let start = points.first!.date
      let end = points.last!.date
      let span = max(end.timeIntervalSince(start), 1)
      let curvePoints = points.map { entry in
        CurvePoint(
          x: Double(plotWidth) * entry.date.timeIntervalSince(start) / span,
          y: Double(plotHeight) * (1 - min(max(entry.value, 0), 1))
        )
      }
      let segments = smoothCurveSegments(through: curvePoints)
      ZStack(alignment: .topLeading) {
        // Gridlines + y labels.
        ForEach(Array(yLabels.enumerated()), id: \.offset) { index, label in
          let y = plotHeight * Double(index) / Double(max(yLabels.count - 1, 1))
          HStack(spacing: 4) {
            Text(label)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .frame(width: yLabelWidth - 6, alignment: .trailing)
            Rectangle()
              .fill(Color.secondary.opacity(0.15))
              .frame(height: 1)
          }
          .frame(width: geometry.size.width, height: 1, alignment: .leading)
          .offset(y: y)
        }
        // Curve + fill.
        ZStack {
          fillPath(segments: segments, height: plotHeight)
            .fill(
              LinearGradient(
                colors: [tint.opacity(0.35), tint.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          linePath(segments: segments)
            .stroke(tint, lineWidth: 1.5)
        }
        .offset(x: yLabelWidth)
        // X labels.
        HStack {
          ForEach(timeAxisMarkers(from: start, to: end, count: 6), id: \.self) { marker in
            Text(Self.timeFormatter.string(from: marker))
              .font(.caption2)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
          }
        }
        .offset(x: yLabelWidth, y: plotHeight + 4)
        .frame(width: plotWidth)
      }
    }
    .clipped()
    .accessibilityHidden(true)
  }

  private func linePath(segments: [CurveSegment]) -> Path {
    Path { path in
      guard let first = segments.first else {
        return
      }
      path.move(to: CGPoint(x: first.start.x, y: first.start.y))
      for segment in segments {
        path.addCurve(
          to: CGPoint(x: segment.end.x, y: segment.end.y),
          control1: CGPoint(x: segment.control1.x, y: segment.control1.y),
          control2: CGPoint(x: segment.control2.x, y: segment.control2.y)
        )
      }
    }
  }

  private func fillPath(segments: [CurveSegment], height: CGFloat) -> Path {
    Path { path in
      guard let first = segments.first, let last = segments.last else {
        return
      }
      path.move(to: CGPoint(x: first.start.x, y: height))
      path.addLine(to: CGPoint(x: first.start.x, y: first.start.y))
      for segment in segments {
        path.addCurve(
          to: CGPoint(x: segment.end.x, y: segment.end.y),
          control1: CGPoint(x: segment.control1.x, y: segment.control1.y),
          control2: CGPoint(x: segment.control2.x, y: segment.control2.y)
        )
      }
      path.addLine(to: CGPoint(x: last.end.x, y: height))
      path.closeSubpath()
    }
  }
}
