import Foundation

/// Minimal lifecycle log for field diagnosis. Writes timestamped lines to
/// ~/Library/Logs/UltimateMacMonitor/debug.log. Synchronous and low-volume
/// by design; safe to keep in the shipping app.
enum AppLog {
  /// Master switch for the debug log (Settings → Store Logs).
  static var isEnabled = true

  /// Size of the debug log on disk, if it exists.
  static var logFileSize: Int? {
    guard let url,
      let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
      let size = values.fileSize
    else {
      return nil
    }
    return size
  }

  /// The folder holding the app's on-disk data (debug log).
  static var dataFolder: URL? {
    url?.deletingLastPathComponent()
  }

  private static var url: URL? {
    let manager = FileManager.default
    guard
      let base = manager.urls(for: .libraryDirectory, in: .userDomainMask).first?
        .appendingPathComponent("Logs/UltimateMacMonitor", isDirectory: true)
    else {
      return nil
    }
    try? manager.createDirectory(at: base, withIntermediateDirectories: true)
    return base.appendingPathComponent("debug.log", isDirectory: false)
  }

  static func event(_ message: String) {
    guard isEnabled else {
      return
    }
    guard let url else {
      return
    }
    let line = "\(ISO8601DateFormatter().string(from: Date())) pid=\(ProcessInfo.processInfo.processIdentifier) \(message)\n"
    guard let data = line.data(using: .utf8) else {
      return
    }
    if FileManager.default.fileExists(atPath: url.path) {
      guard let handle = try? FileHandle(forWritingTo: url) else {
        return
      }
      defer { try? handle.close() }
      _ = try? handle.seekToEnd()
      try? handle.write(contentsOf: data)
    } else {
      try? data.write(to: url)
    }
  }
}
