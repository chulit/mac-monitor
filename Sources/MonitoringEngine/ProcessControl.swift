import Foundation

public struct ControlledProcess: Sendable, Equatable {
  public let pid: Int
  public let identityToken: String
  public let name: String

  public init(pid: Int, identityToken: String, name: String) {
    self.pid = pid
    self.identityToken = identityToken
    self.name = name
  }
}

public enum ProcessExecutorError: Sendable, Equatable, Error {
  case permissionDenied
  case systemProtected
}

public protocol ProcessExecutor {
  func identityToken(for pid: Int) -> String?
  func terminate(pid: Int, forcefully: Bool) throws
}

public enum ControlRefusal: Sendable, Equatable {
  case permissionDenied
  case systemProtected
  case alreadyExited
  case failed(String)

  public var explanation: String {
    switch self {
    case .permissionDenied:
      return "Termination was refused: the request lacks permission for this process."
    case .systemProtected:
      return "Termination was refused: the process is protected by the system."
    case .alreadyExited:
      return "No action taken: the process had already exited."
    case .failed(let detail):
      return "Termination failed: \(detail)."
    }
  }
}

public enum ControlResult: Sendable, Equatable {
  case exited
  case confirmationRequired(count: Int)
  case identityChanged
  case refused(ControlRefusal)
}

public final class ProcessControl<E: ProcessExecutor> {
  private let executor: E

  public init(executor: E) {
    self.executor = executor
  }

  public func terminate(_ target: ControlledProcess, confirmations: Int) -> ControlResult {
    guard confirmations >= 1 else {
      return .confirmationRequired(count: 1)
    }
    return act(on: target, forcefully: false)
  }

  public func forceQuit(_ target: ControlledProcess, confirmations: Int) -> ControlResult {
    guard confirmations >= 2 else {
      return .confirmationRequired(count: 2)
    }
    return act(on: target, forcefully: true)
  }

  private func act(on target: ControlledProcess, forcefully: Bool) -> ControlResult {
    guard let current = executor.identityToken(for: target.pid) else {
      return .refused(.alreadyExited)
    }
    guard current == target.identityToken else {
      return .identityChanged
    }
    do {
      try executor.terminate(pid: target.pid, forcefully: forcefully)
      return .exited
    } catch let executorError as ProcessExecutorError {
      switch executorError {
      case .permissionDenied:
        return .refused(.permissionDenied)
      case .systemProtected:
        return .refused(.systemProtected)
      }
    } catch {
      return .refused(.failed(String(describing: error)))
    }
  }
}
