import SwiftUI
import MonitoringEngine

/// Minimal sparkline drawn as explicit paths and clipped to its frame.
/// Used instead of Charts in dense card layouts, where a chart plot area
/// can overflow its bounds and wash across the surrounding interface.
struct Sparkline: View {
  var values: [(date: Date, value: Double)]
  var tint: Color

  var body: some View {
    // BISECT ROUND 4 (Ship-21): Sparkline body disabled. If the popover
    // lives, this body is the killer; helpers below go quiet meanwhile.
    EmptyView().frame(height: 28)
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
