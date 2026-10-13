import SwiftUI

@main
struct MonitorApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var controller = EngineController()

  var body: some Scene {
    WindowGroup {
      RootView(controller: controller, store: delegate.navigation)
        .onAppear {
          delegate.bind(controller)
          controller.start()
        }
    }
  }
}
