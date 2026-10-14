import AppKit
import SwiftUI

/// The real app logo, loaded once from the bundled `AppIcon.png` asset.
/// If the asset is missing the view renders empty space: a missing logo
/// is a packaging bug and must stay visible, never silently covered by a
/// fake placeholder.
struct AppLogo: View {
  let size: CGFloat

  /// Loaded once — `body` must never hit the disk on every evaluation.
  private static let cachedImage: NSImage? = {
    guard
      let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png")
    else {
      return nil
    }
    return NSImage(contentsOf: url)
  }()

  var body: some View {
    if let image = Self.cachedImage {
      Image(nsImage: image)
        .resizable()
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
        .accessibilityHidden(true)
    } else {
      Color.clear
        .frame(width: size, height: size)
    }
  }
}
