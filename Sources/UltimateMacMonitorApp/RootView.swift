import SwiftUI

/// Full window: sidebar navigation across the three screens.
struct RootView: View {
  @ObservedObject var controller: EngineController
  @State private var selection: Section? = .dashboard

  enum Section: Hashable {
    case dashboard
    case investigation
    case processes
  }

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
          .tag(Section.dashboard)
        Label("Investigation", systemImage: "timeline.selection")
          .tag(Section.investigation)
        Label("Processes", systemImage: "list.bullet")
          .tag(Section.processes)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
      switch selection ?? .dashboard {
      case .dashboard:
        DashboardView(controller: controller)
      case .investigation:
        TimelineView(controller: controller)
      case .processes:
        ProcessTreeView(controller: controller)
      }
    }
    .frame(minWidth: 760, minHeight: 480)
  }
}
