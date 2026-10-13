import SwiftUI
import MonitoringEngine

/// Minimal sparkline drawn as explicit paths and clipped to its frame.
/// Used instead of Charts in dense card layouts, where a chart plot area
/// can overflow its bounds and wash across the surrounding interface.
struct Sparkline: View {
  var values: [(date: Date, value: Double)]
  var tint: Color

  var body: some View {
    GeometryReader { geometry in
      let domain = chartDomain(values: values.map(\.value))
      let span = max(domain.upperBound - domain.lowerBound, 1e-9)
      let points = values.enumerated().map { index, entry in
        CGPoint(
          x: values.count > 1
            ? geometry.size.width * Double(index) / Double(values.count - 1) : geometry.size.width / 2,
          y: geometry.size.height * (1 - (entry.value - domain.lowerBound) / span)
        )
      }
      ZStack {
        fillPath(points: points, height: geometry.size.height)
          .fill(tint.opacity(0.25))
        linePath(points: points)
          .stroke(tint, lineWidth: 1.5)
      }
    }
    .frame(height: 28)
    .clipped()
  }

  private func linePath(points: [CGPoint]) -> Path {
    Path { path in
      guard let first = points.first else {
        return
      }
      path.move(to: first)
      for point in points.dropFirst() {
        path.addLine(to: point)
      }
    }
  }

  private func fillPath(points: [CGPoint], height: Double) -> Path {
    Path { path in
      guard let first = points.first, let last = points.last else {
        return
      }
      path.move(to: CGPoint(x: first.x, y: height))
      path.addLine(to: first)
      for point in points.dropFirst() {
        path.addLine(to: point)
      }
      path.addLine(to: CGPoint(x: last.x, y: height))
      path.closeSubpath()
    }
  }
}
