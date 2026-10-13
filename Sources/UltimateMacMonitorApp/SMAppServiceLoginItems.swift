import Foundation
import MonitoringEngine
import ServiceManagement

/// The real login-item state via SMAppService (macOS 13+).
///
/// Only works in a properly bundled app. Under `swift run` the register call
/// throws, and the settings window surfaces that error instead of pretending
/// the toggle worked.
final class SMAppServiceLoginItems: LoginItemService {
  func isEnabled() -> Bool {
    SMAppService.mainApp.status == .enabled
  }

  func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }
}
