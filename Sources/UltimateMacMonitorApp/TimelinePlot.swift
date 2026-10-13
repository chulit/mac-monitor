import MonitoringEngine
import SwiftUI

/// The interactive plot inside the usage timeline card (overview issue 04):
/// Y gridlines, X time markers, a smooth bezier area curve, and a scrub
/// tooltip with a vertical guideline and data-point dot.
///
/// A separate view type with narrow `let` inputs, so it is its own
/// invalidation boundary and does not re-evaluate when unrelated controller
/// state changes.
struct TimelinePlot: View {
  let samples: [(date: Date, value: Double)]
  let windowStart: Date
  let windowEnd: Date
  let metric: TimelineMetric
  let tint: Color
  let rangeLabel: String

  /// The time currently under the user's finger/cursor while scrubbing.
  @State private var inspectedTime: Date? = nil

  private let yLabelWidth: CGFloat = 46
  private let xLabelHeight: CGFloat = 20
  private let topPadding: CGFloat = 8

  private static let hourMinute: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  private static let fullTime: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  var body: some View {
    GeometryReader { geometry in
      let plot = plotRect(in: geometry.size)
      let ticks = yAxisTicks(values: samples.map(\.value), fractional: metric.isFractional)
      let yMax = max(ticks.first?.value ?? 1, 1e-9)
      let markers = timeAxisMarkers(from: windowStart, to: windowEnd, count: 6)
      let segments = smoothCurveSegments(
        through: samples.map {
          CurvePoint(
            x: xPosition(for: $0.date, plot: plot),
            y: yPosition(for: $0.value, plot: plot, yMax: yMax)
          )
        }
      )
      let inspected = inspectedSample()

      ZStack {
        gridlines(ticks: ticks, plot: plot, yMax: yMax)
        areaCurve(segments: segments, plot: plot)
        if let inspected {
          inspectionMark(sample: inspected, plot: plot, yMax: yMax)
        }
        axisLabels(
          ticks: ticks, markers: markers, plot: plot, yMax: yMax, size: geometry.size
        )
        if let inspected {
          tooltip(sample: inspected, plot: plot, yMax: yMax)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(accessibilitySummary)
      .gesture(scrubGesture(plot: plot))
    }
    .frame(height: 220)
  }

  private func plotRect(in size: CGSize) -> CGRect {
    CGRect(
      x: yLabelWidth,
      y: topPadding,
      width: max(size.width - yLabelWidth - 8, 1),
      height: max(size.height - xLabelHeight - topPadding, 1)
    )
  }

  private func xPosition(for date: Date, plot: CGRect) -> CGFloat {
    let span = max(windowEnd.timeIntervalSince(windowStart), 1e-9)
    let fraction = min(max(date.timeIntervalSince(windowStart) / span, 0), 1)
    return plot.minX + plot.width * CGFloat(fraction)
  }

  private func time(at x: CGFloat, plot: CGRect) -> Date {
    let fraction = min(max(Double((x - plot.minX) / plot.width), 0), 1)
    return windowStart.addingTimeInterval(windowEnd.timeIntervalSince(windowStart) * fraction)
  }

  private func yPosition(for value: Double, plot: CGRect, yMax: Double) -> CGFloat {
    plot.maxY - plot.height * CGFloat(min(max(value / yMax, 0), 1))
  }

  private func readingText(_ value: Double) -> String {
    metric.isFractional ? "\(Int((value * 100).rounded()))%" : formatRate(value)
  }

  private func inspectedSample() -> (date: Date, value: Double)? {
    guard let inspectedTime else {
      return nil
    }
    return nearestSample(at: inspectedTime, in: samples)
  }

  private var accessibilitySummary: String {
    let current = samples.last.map(readingText) ?? "no data"
    return "\(metric.title) over the last \(rangeLabel), currently \(current)"
  }

  private func scrubGesture(plot: CGRect) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        inspectedTime = time(at: value.location.x, plot: plot)
      }
      .onEnded { _ in
        inspectedTime = nil
      }
  }

  private func gridlines(ticks: [AxisTick], plot: CGRect, yMax: Double) -> some View {
    Path { path in
      for tick in ticks {
        let y = yPosition(for: tick.value, plot: plot, yMax: yMax)
        path.move(to: CGPoint(x: plot.minX, y: y))
        path.addLine(to: CGPoint(x: plot.maxX, y: y))
      }
    }
    .stroke(Color.gray.opacity(0.18), lineWidth: 1)
  }

  private func areaCurve(segments: [CurveSegment], plot: CGRect) -> some View {
    ZStack {
      Path { path in
        guard let first = segments.first, let last = segments.last else {
          return
        }
        path.move(to: CGPoint(x: first.start.x, y: plot.maxY))
        path.addLine(to: CGPoint(x: first.start.x, y: first.start.y))
        for segment in segments {
          path.addCurve(
            to: CGPoint(x: segment.end.x, y: segment.end.y),
            control1: CGPoint(x: segment.control1.x, y: segment.control1.y),
            control2: CGPoint(x: segment.control2.x, y: segment.control2.y)
          )
        }
        path.addLine(to: CGPoint(x: last.end.x, y: plot.maxY))
        path.closeSubpath()
      }
      .fill(
        LinearGradient(
          colors: [tint.opacity(0.35), tint.opacity(0.02)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
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
      .stroke(tint, lineWidth: 1.5)
    }
  }

  private func inspectionMark(
    sample: (date: Date, value: Double), plot: CGRect, yMax: Double
  ) -> some View {
    let x = xPosition(for: sample.date, plot: plot)
    let y = yPosition(for: sample.value, plot: plot, yMax: yMax)
    return ZStack {
      Path { path in
        path.move(to: CGPoint(x: x, y: plot.minY))
        path.addLine(to: CGPoint(x: x, y: plot.maxY))
      }
      .stroke(Color.gray.opacity(0.5), lineWidth: 1)
      Circle()
        .fill(tint)
        .frame(width: 8, height: 8)
        .position(x: x, y: y)
    }
  }

  private func axisLabels(
    ticks: [AxisTick], markers: [Date], plot: CGRect, yMax: Double, size: CGSize
  ) -> some View {
    ZStack {
      ForEach(ticks, id: \.value) { tick in
        Text(tick.label)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .position(x: yLabelWidth / 2, y: yPosition(for: tick.value, plot: plot, yMax: yMax))
      }
      ForEach(markers, id: \.self) { marker in
        Text(Self.hourMinute.string(from: marker))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .position(
            x: xPosition(for: marker, plot: plot),
            y: size.height - xLabelHeight / 2
          )
      }
    }
  }

  private func tooltip(sample: (date: Date, value: Double), plot: CGRect, yMax: Double) -> some View {
    let x = xPosition(for: sample.date, plot: plot)
    let tooltipWidth: CGFloat = 140
    let clampedX = min(max(x, tooltipWidth / 2 + 4), plot.maxX - tooltipWidth / 2 + 8)
    let dotY = yPosition(for: sample.value, plot: plot, yMax: yMax)
    return VStack(alignment: .leading, spacing: 2) {
      Text(Self.fullTime.string(from: sample.date))
        .font(.caption2)
        .foregroundStyle(.secondary)
      HStack(spacing: 4) {
        Circle()
          .fill(tint)
          .frame(width: 6, height: 6)
          .accessibilityHidden(true)
        Text("\(metric.pillTitle) \(readingText(sample.value))")
          .font(.caption.bold())
      }
    }
    .padding(8)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    .position(x: clampedX, y: max(dotY - 36, 30))
  }
}
