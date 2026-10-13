import SwiftUI

@main
struct MonitorApp: App {
  @StateObject private var controller = EngineController()

  var body: some Scene {
    WindowGroup {
      TabView {
        DashboardView(controller: controller)
          .tabItem {
            Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
          }
        TimelineView(controller: controller)
          .tabItem {
            Label("Investigation", systemImage: "timeline.selection")
          }
        ProcessTreeView(controller: controller)
          .tabItem {
            Label("Processes", systemImage: "list.bullet")
          }
      }
      .onAppear {
        controller.start()
      }
    }
  }
}
