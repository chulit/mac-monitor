import Foundation

/// Real machine facts for the About panel. Everything here is read from the
/// running system; nothing is hardcoded.
enum SystemInfo {
  static var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
  }

  static var appBuild: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
  }

  static var macOSVersion: String {
    ProcessInfo.processInfo.operatingSystemVersionString
  }

  static var chipName: String {
    sysctlString("machdep.cpu.brand_string") ?? "Unknown chip"
  }

  static var modelID: String {
    sysctlString("hw.model") ?? "Unknown model"
  }

  static var memoryGB: String {
    let bytes = Double(ProcessInfo.processInfo.physicalMemory)
    return String(format: "%.0f GB", bytes / 1_073_741_824)
  }

  static var releasesURL: URL {
    URL(string: "https://github.com/chulit/mac-monitor/releases")!
  }

  static var repositoryURL: URL {
    URL(string: "https://github.com/chulit/mac-monitor")!
  }

  static var newIssueURL: URL {
    URL(string: "https://github.com/chulit/mac-monitor/issues/new")!
  }

  private static func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
      return nil
    }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
      return nil
    }
    return String(cString: buffer)
  }
}
