import MonitoringEngine
import SwiftUI

/// Multi-day system activity chart (issue 01): bucketed area curve for one
/// metric with a drag-to-inspect tooltip. Points come from
/// `activitySeries`, which merges detail samples with compact summaries.
struct HistoryActivityChart: View {
  let points: [ActivityPoint]
  let metric: String
  let range: HistoryRange

  @State private var inspectedDate: Date?

  private static let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d"
    return formatter
  }()

  private static let hourFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  private static let tooltipFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
  }()

  private var isFractionMetric: Bool {
    ["cpu", "memory", "disk"].contains(metric)
  }

  private var yDomain: (lower: Double, upper: Double) {
    if isFractionMetric {
      return (0, 1)
    }
    let values = points.map(\.value)
    guard let min = values.min(), let max = values.max(), max > min else {
      return (0, 1)
    }
    let pad = (max - min) * 0.1
    return (min - pad, max + pad)
  }

  private var yLabels: [String] {
    let (lower, upper) = yDomain
    return (0...4).map { index in
      let value = lower + (upper - lower) * Double(4 - index) / 4
      return formatValue(value)
    }
  }

  func formatValue(_ value: Double) -> String {
    switch metric {
    case "cpu", "memory", "disk":
      return String(format: "%.0f%%", value * 100)
    case "network":
      return formatRate(value)
    case "temperature":
      return String(format: "%.0f°", value)
    default:
      return String(format: "%.1f", value)
    }
  }

  func formatRate(_ bytesPerSecond: Double) -> String {
    if bytesPerSecond >= 1_000_000 {
      return String(format: "%.0f MB/s", bytesPerSecond / 1_000_000)
    }
    if bytesPerSecond >= 1_000 {
      return String(format: "%.0f KB/s", bytesPerSecond / 1_000)
    }
    return String(format: "%.0f B/s", bytesPerSecond)
  }

  private var xLabelFormatter: DateFormatter {
    range == .day ? Self.hourFormatter : Self.dayFormatter
  }

  private let yLabelWidth: CGFloat = 52
  private let xLabelHeight: CGFloat = 18

  var body: some View {
    Group {
      if points.count >= 2 {
        chart
          .frame(height: 220)
      } else {
        Text("No \(metricDisplayName) samples were recorded in this range.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
      }
    }
  }

  private var metricDisplayName: String {
    switch metric {
    case "cpu": return "CPU"
    case "memory": return "Memory"
    case "disk": return "Disk"
    case "network": return "Network"
    case "temperature": return "Temperature"
    default: return metric.capitalized
    }
  }

  private var chart: some View {
    GeometryReader { geometry in
      let plotWidth = geometry.size.width - yLabelWidth
      let plotHeight = geometry.size.height - xLabelHeight
      let start = points.first!.date
      let end = points.last!.date
      let span = max(end.timeIntervalSince(start), 1)
      let (lower, upper) = yDomain
      let valueSpan = max(upper - lower, 1e-9)
      func x(for date: Date) -> Double {
        Double(plotWidth) * date.timeIntervalSince(start) / span
      }
      func y(for value: Double) -> Double {
        Double(plotHeight) * (1 - (value - lower) / valueSpan)
      }
      let curvePoints = points.map { CurvePoint(x: x(for: $0.date), y: y(for: $0.value)) }
      let segments = smoothCurveSegments(through: curvePoints)
      ZStack(alignment: .topLeading) {
        ForEach(Array(yLabels.enumerated()), id: \.offset) { index, label in
          let yPos = plotHeight * Double(index) / Double(max(yLabels.count - 1, 1))
          HStack(spacing: 4) {
            Text(label)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .frame(width: yLabelWidth - 6, alignment: .trailing)
            Rectangle()
              .fill(Color.secondary.opacity(0.15))
              .frame(height: 1)
          }
          .frame(width: geometry.size.width, alignment: .leading)
          .offset(y: yPos)
        }
        ZStack {
          fillPath(segments: segments, height: plotHeight)
            .fill(
              LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          linePath(segments: segments)
            .stroke(Color.blue, lineWidth: 1.5)
        }
        .offset(x: yLabelWidth)
        if let inspected = inspectedPoint {
          let ix = x(for: inspected.date)
          Rectangle()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 1, height: plotHeight)
            .offset(x: yLabelWidth + CGFloat(ix))
          Circle()
            .fill(Color.blue)
            .frame(width: 8, height: 8)
            .offset(
              x: yLabelWidth + CGFloat(ix) - 4,
              y: CGFloat(y(for: inspected.value)) - 4
            )
          VStack(alignment: .leading, spacing: 2) {
            Text(Self.tooltipFormatter.string(from: inspected.date))
              .font(.caption2)
              .foregroundStyle(.secondary)
            HStack(spacing: 6) {
              Circle()
                .fill(Color.blue)
                .frame(width: 8, height: 8)
              Text(metricDisplayName)
                .font(.caption)
              Text(formatValue(inspected.value))
                .font(.caption.bold().monospacedDigit())
            }
          }
          .padding(.horizontal, 8)
          .padding(.vertical, 6)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
          .offset(
            x: min(max(yLabelWidth + CGFloat(ix) - 70, yLabelWidth), yLabelWidth + CGFloat(plotWidth) - 150),
            y: 4
          )
        }
        HStack {
          ForEach(timeAxisMarkers(from: start, to: end, count: 7), id: \.self) { marker in
            Text(xLabelFormatter.string(from: marker))
              .font(.caption2)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .center)
          }
        }
        .offset(x: yLabelWidth, y: plotHeight + 4)
        .frame(width: plotWidth)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            let px = min(max(value.location.x - yLabelWidth, 0), plotWidth)
            inspectedDate = start.addingTimeInterval(span * Double(px) / Double(plotWidth))
          }
          .onEnded { _ in
            inspectedDate = nil
          }
      )
    }
    .clipped()
  }

  private var inspectedPoint: ActivityPoint? {
    guard let date = inspectedDate else {
      return nil
    }
    return points.min {
      abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
    }
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
