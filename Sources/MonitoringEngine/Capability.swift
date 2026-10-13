import Darwin
import Foundation

/// Declares which metrics each hardware architecture provides. Both
/// supported architectures share the same Mach-based collectors today, so
/// the rows match; the structure exists so a future device-only metric
/// diverges by row instead of by special case. Unknown architectures
/// support nothing: unproven hardware reports unavailable, never assumed.
public struct CapabilityMatrix: Sendable, Equatable {
  public let architecture: String

  public init(architecture: String) {
    self.architecture = architecture
  }

  public static func current() -> CapabilityMatrix {
    CapabilityMatrix(architecture: hardwareMachine())
  }

  public static func forArchitecture(_ name: String) -> CapabilityMatrix {
    CapabilityMatrix(architecture: name)
  }

  public var systemMetrics: Set<String> {
    switch architecture {
    case "arm64", "x86_64":
      return ["cpu", "memory", "disk", "network"]
    default:
      return []
    }
  }

  public var processMetrics: Set<String> {
    switch architecture {
    case "arm64", "x86_64":
      return ["cpu"]
    default:
      return []
    }
  }

  public func supports(_ metric: String) -> Bool {
    systemMetrics.contains(metric) || processMetrics.contains(metric)
  }

  private static func hardwareMachine() -> String {
    var size = 0
    let absentOld: UnsafeMutableRawPointer? = nil
    let absentNew: UnsafeMutableRawPointer? = nil
    guard sysctlbyname("hw.machine", absentOld, &size, absentNew, 0) == 0, size > 0 else {
      return "unknown"
    }
    var buffer = [CChar](repeating: 0, count: size)
    let machine: String? = buffer.withUnsafeMutableBufferPointer { pointer in
      guard sysctlbyname("hw.machine", pointer.baseAddress, &size, absentNew, 0) == 0,
        let base = pointer.baseAddress
      else {
        return nil
      }
      return String(cString: base)
    }
    return machine ?? "unknown"
  }
}
