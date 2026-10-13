import SwiftUI

@main
struct MonitorApp: App {
  @StateObject private var controller = EngineController()

  var body: some Scene {
    WindowGroup {
      DashboardView(controller: controller)
        .onAppear {
          controller.start()
        }
    }
  }
}
