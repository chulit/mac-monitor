import SwiftUI

/// Slim rounded progress bar shared by the top-process rows and the
/// investigation phase tracker.
struct SlimProgressBar: View {
  /// 0...1, clamped.
  var value: Double
  var tint: Color

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 3)
          .fill(tint.opacity(0.15))
        RoundedRectangle(cornerRadius: 3)
          .fill(tint)
          .frame(width: geometry.size.width * CGFloat(min(max(value, 0), 1)))
      }
    }
    .frame(height: 6)
  }
}
