import AppKit
import SwiftUI

/// The real app logo, loaded from the bundled `AppIcon.png` asset.
/// Falls back to the gradient placeholder when the asset is missing
/// (e.g. a build that skipped target resources) so the UI never shows
/// a blank hole.
struct AppLogo: View {
  let size: CGFloat

  private var cornerRadius: CGFloat { size * 0.28 }

  var body: some View {
    if let image = bundledImage {
      Image(nsImage: image)
        .resizable()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    } else {
      RoundedRectangle(cornerRadius: cornerRadius)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.04, green: 0.06, blue: 0.18),
              Color(red: 0.10, green: 0.16, blue: 0.45),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: size, height: size)
        .overlay(
          Image(systemName: "waveform")
            .font(.body)
            .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))
        )
        .accessibilityHidden(true)
    }
  }

  private var bundledImage: NSImage? {
    guard
      let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else {
      return nil
    }
    return image
  }
}
