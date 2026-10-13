import AppKit
import Darwin
import Foundation
import MonitoringEngine

/// Honest per-process metadata resolved on macOS. Anything the system does
/// not report stays nil — the UI renders "—", never a fabricated value.
struct ProcessMetadata {
  let bundleID: String?
  let version: String?
  let executablePath: String?
  let launchDate: Date?
  let isApplication: Bool

  static func resolve(process: Process) -> ProcessMetadata {
    guard let pid = Int32(process.id) else {
      return ProcessMetadata(
        bundleID: nil, version: nil, executablePath: nil, launchDate: nil, isApplication: false
      )
    }
    let app = NSRunningApplication(processIdentifier: pid)
    let executablePath =
      app?.executableURL?.path ?? executablePathViaLibproc(pid: pid)
    let version =
      app?.bundleURL
      .flatMap { Bundle(url: $0) }?
      .infoDictionary?["CFBundleShortVersionString"] as? String
    return ProcessMetadata(
      bundleID: app?.bundleIdentifier,
      version: version,
      executablePath: executablePath,
      launchDate: app?.launchDate,
      isApplication: app?.activationPolicy == .regular
    )
  }

  private static func executablePathViaLibproc(pid: Int32) -> String? {
    var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else {
      return nil
    }
    return String(cString: buffer)
  }
}

/// Real executor behind the safe termination flow: identity tokens come
/// from the same libproc start-time binding the collector uses, so a
/// reused PID fails the identity check instead of killing the wrong
/// process.
struct DarwinProcessExecutor: ProcessExecutor {
  func identityToken(for pid: Int) -> String? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(Int32(pid), PROC_PIDTBSDINFO, 0, &info, size) == size else {
      return nil
    }
    return "\(info.pbi_pid)-\(info.pbi_start_tvsec)-\(info.pbi_start_tvusec)"
  }

  func terminate(pid: Int, forcefully: Bool) throws {
    let signal = forcefully ? SIGKILL : SIGTERM
    guard kill(pid_t(pid), signal) == 0 else {
      switch errno {
      case EPERM:
        throw ProcessExecutorError.permissionDenied
      default:
        // A stale PID that slipped past the identity check surfaces here
        // as a plain POSIX error, reported verbatim to the user.
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: nil)
      }
    }
  }
}
