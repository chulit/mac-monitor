import SwiftUI

/// Full window: sidebar navigation across the three screens. Selection
/// lives in the navigation store so the popover can deep-link into it.
struct RootView: View {
  @ObservedObject var controller: EngineController
  @ObservedObject var store: NavigationStore

  var body: some View {
    NavigationSplitView {
      List(
        selection: Binding(
          get: { store.section },
          set: { store.section = $0 }
        )
      ) {
        Label("Dashboard", systemImage: "gauge.with.dots.needle.67percent")
          .tag(AppSection.dashboard)
        Label("Investigation", systemImage: "timeline.selection")
          .tag(AppSection.investigation)
        Label("Processes", systemImage: "list.bullet")
          .tag(AppSection.processes)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
      switch store.section ?? .dashboard {
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
