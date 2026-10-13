import SwiftUI
import MonitoringEngine

/// Minimal sparkline drawn as explicit paths and clipped to its frame.
/// Replaces Charts in dense card layouts, where a chart plot area overflowed
/// its bounds and washed across the popover. Inputs are sanitized: a single
/// non-finite reading used to take the whole popover down with it.
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
          CGPoint(
            x: geometry.size.width * Double(index) / Double(clean.count - 1),
            y: geometry.size.height * (1 - (entry.value - domain.lowerBound) / span)
          )
        }
        ZStack {
          fillPath(points: points, height: geometry.size.height)
            .fill(
              LinearGradient(
                colors: [tint.opacity(0.35), tint.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
              )
            )
          linePath(points: points)
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
