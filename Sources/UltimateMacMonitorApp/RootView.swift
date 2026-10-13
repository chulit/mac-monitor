import MonitoringEngine
import SwiftUI

/// Full window: sidebar navigation across the five sections. Selection
/// lives in the navigation store so the popover can deep-link into it.
///
/// The Settings row opens the settings window (issue 19) instead of a detail
/// view; the sidebar selection snaps back to the previous section.
struct RootView: View {
  @ObservedObject var controller: EngineController
  @ObservedObject var store: NavigationStore
  var onOpenSettings: () -> Void = {}

  @State private var previousSection: AppSection = .overview

  var body: some View {
    NavigationSplitView {
      VStack(alignment: .leading, spacing: 0) {
        appHeader
        List(
          selection: Binding(
            get: { store.section },
            set: { store.section = $0 }
          )
        ) {
          ForEach(AppSection.allCases, id: \.self) { section in
            sidebarLabel(for: section)
          }
        }
        .listStyle(.sidebar)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
      switch store.section ?? .overview {
      case .overview:
        DashboardView(controller: controller) { section in
          store.section = section
        }
      case .processes:
        ProcessesView(controller: controller)
      case .incidents:
        TimelineView(controller: controller)
      case .history:
        historyPlaceholder
      case .settings:
        EmptyView()
      }
    }
    .onChange(of: store.section) { newSection in
      guard let newSection else { return }
      if newSection == .settings {
        onOpenSettings()
        store.section = previousSection
      } else {
        previousSection = newSection
      }
    }
    .frame(minWidth: 760, minHeight: 480)
  }

  // MARK: Sidebar

  private var appHeader: some View {
    HStack(spacing: 10) {
      RoundedRectangle(cornerRadius: 10)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.04, green: 0.06, blue: 0.18),
              Color(red: 0.10, green: 0.16, blue: 0.45),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .frame(width: 36, height: 36)
        .overlay(
          Image(systemName: "waveform")
            .font(.body)
            .foregroundStyle(Color(red: 0.35, green: 0.65, blue: 1.0))
        )
      Text("Ultimate Mac Monitor")
        .font(.headline)
    }
    .padding(.horizontal)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private func sidebarLabel(for section: AppSection) -> some View {
    let label = Label(section.title, systemImage: section.icon).tag(section)
    // The badge is the live active-incident count, never a hardcoded number.
    if section == .incidents, controller.activeIncidentCount > 0 {
      label.badge(controller.activeIncidentCount)
    } else {
      label
    }
  }

  // MARK: Detail

  /// Temporary until the History module lands its real views.
  private var historyPlaceholder: some View {
    VStack(spacing: 12) {
      Image(systemName: "clock")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("History")
        .font(.title2.bold())
      Text("Multi-day trends and the incident archive arrive with the History module.")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
