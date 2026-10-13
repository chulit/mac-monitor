import MonitoringEngine
import SwiftUI

/// Incident timeline chart (issue 04): metric tabs, smooth area curve, the
/// shaded incident span, a peak marker, and drag-to-inspect tooltips.
/// Everything plotted comes from the timeline's own samples.
struct IncidentTimelineChart: View {
  let timeline: IncidentTimeline
  let incident: Incident

  @State private var selectedMetric: String
  @State private var inspectedDate: Date?

  init(timeline: IncidentTimeline, incident: Incident) {
    self.timeline = timeline
    self.incident = incident
    _selectedMetric = State(initialValue: timeline.metricSamples.first?.metric ?? "cpu")
  }

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  private static let fullTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  private var metrics: [String] {
    Array(Set(timeline.metricSamples.map(\.metric))).sorted()
  }

  private var samples: [(date: Date, value: Double)] {
    timeline.metricSamples
      .filter { $0.metric == selectedMetric }
      .compactMap { sample in sample.value.map { (sample.timestamp, $0) } }
      .sorted { $0.date < $1.date }
  }

  /// Fraction metrics (cpu/memory/disk) render on a fixed 0...1 axis;
  /// anything else uses a padded data domain.
  private var isFractionMetric: Bool {
    ["cpu", "memory", "disk"].contains(selectedMetric)
  }

  private var yDomain: (lower: Double, upper: Double) {
    if isFractionMetric {
      return (0, 1)
    }
    let values = samples.map(\.value)
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
      if isFractionMetric {
        return String(format: "%.0f%%", value * 100)
      }
      return String(format: "%.1f", value)
    }
  }

  private var peakSample: (date: Date, value: Double)? {
    samples.max { $0.value < $1.value }
  }

  private func formatValue(_ value: Double) -> String {
    isFractionMetric ? String(format: "%.0f%%", value * 100) : String(format: "%.1f", value)
  }

  private let yLabelWidth: CGFloat = 46
  private let xLabelHeight: CGFloat = 18

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      metricTabs
      if samples.count >= 2 {
        chart
          .frame(height: 190)
      } else {
        Text("No \(selectedMetric) samples were recorded for this incident.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 190, alignment: .center)
      }
    }
    .dashboardCardStyle()
  }

  private var metricTabs: some View {
    HStack(spacing: 4) {
      ForEach(metrics, id: \.self) { metric in
        Button {
          selectedMetric = metric
          inspectedDate = nil
        } label: {
          Text(metricLabel(metric))
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              selectedMetric == metric ? Color.accentColor.opacity(0.12) : Color.clear,
              in: RoundedRectangle(cornerRadius: 8)
            )
            .foregroundStyle(selectedMetric == metric ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func metricLabel(_ metric: String) -> String {
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
      let points = samples
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
      // Incident span, clamped to the plot.
      let spanStart = min(max(x(for: incident.startedAt), 0), Double(plotWidth))
      let spanEnd = min(
        max(x(for: incident.recoveredAt ?? Date()), 0), Double(plotWidth)
      )
      ZStack(alignment: .topLeading) {
        // Shaded incident span.
        if spanEnd > spanStart {
          Rectangle()
            .fill(Color.red.opacity(0.08))
            .frame(width: CGFloat(spanEnd - spanStart), height: plotHeight)
            .offset(x: yLabelWidth + CGFloat(spanStart))
        }
        // Gridlines + y labels.
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
        // Area + curve.
        ZStack {
          fillPath(segments: segments, height: plotHeight)
            .fill(
              LinearGradient(
                colors: [Color.red.opacity(0.3), Color.red.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          linePath(segments: segments)
            .stroke(Color.red, lineWidth: 1.5)
        }
        .offset(x: yLabelWidth)
        // Peak marker.
        if let peak = peakSample {
          Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .offset(x: yLabelWidth + CGFloat(x(for: peak.date)) - 4, y: CGFloat(y(for: peak.value)) - 4)
        }
        // Inspection guideline + tooltip.
        if let inspected = inspectedSample(at: inspectedDate, points: points) {
          let ix = x(for: inspected.date)
          Rectangle()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 1, height: plotHeight)
            .offset(x: yLabelWidth + CGFloat(ix))
          Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .offset(
              x: yLabelWidth + CGFloat(ix) - 4,
              y: CGFloat(y(for: inspected.value)) - 4
            )
          Text(
            "\(Self.fullTimeFormatter.string(from: inspected.date)) • \(metricLabel(selectedMetric)) \(formatValue(inspected.value))"
          )
          .font(.caption)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
          .offset(
            x: min(max(yLabelWidth + CGFloat(ix) - 60, yLabelWidth), yLabelWidth + CGFloat(plotWidth) - 130),
            y: 4
          )
        }
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

  private func inspectedSample(
    at date: Date?,
    points: [(date: Date, value: Double)]
  ) -> (date: Date, value: Double)? {
    guard let date else {
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
