import AppKit
import MonitoringEngine
import SwiftUI

/// Real application icon for a process via NSRunningApplication, falling
/// back to a generic glyph for daemons and kernel tasks.
struct ProcessAppIcon: View {
  let process: Process

  var body: some View {
    Group {
      if let pid = Int32(process.id),
        let icon = NSRunningApplication(processIdentifier: pid)?.icon
      {
        Image(nsImage: icon)
          .resizable()
      } else {
        Image(systemName: "app.fill")
          .resizable()
          .foregroundStyle(.secondary)
      }
    }
    .aspectRatio(contentMode: .fit)
    .accessibilityHidden(true)
  }
}
