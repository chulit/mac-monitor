import SwiftUI
import MonitoringEngine

/// Minimal sparkline drawn as explicit paths and clipped to its frame.
/// Replaces Charts in dense card layouts, where a chart plot area overflowed
/// its bounds and washed across the popover. Inputs are sanitized: a single
/// non-finite reading used to take the whole popover down with it.
/// The line is a smooth cubic-bezier curve through every point.
struct Sparkline: View {
  var values: [(date: Date, value: Double)]
  var tint: Color

  var body: some View {
    let clean = values.filter { $0.value.isFinite }
    if clean.count >= 2 {
      GeometryReader { geometry in
        let domain = chartDomain(values: clean.map(\.value))
        let span = max(domain.upperBound - domain.lowerBound, 1e-9)
        let points = clean.enumerated().map { index, entry in
          CurvePoint(
            x: geometry.size.width * Double(index) / Double(clean.count - 1),
            y: geometry.size.height * (1 - (entry.value - domain.lowerBound) / span)
          )
        }
        let segments = smoothCurveSegments(through: points)
        ZStack {
          fillPath(segments: segments, height: geometry.size.height)
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
      }
      .frame(height: 28)
      .clipped()
    } else {
      RoundedRectangle(cornerRadius: 2)
        .fill(tint.opacity(0.15))
        .frame(height: 28)
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

  private func fillPath(segments: [CurveSegment], height: Double) -> Path {
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
