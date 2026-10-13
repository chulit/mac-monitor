import MonitoringEngine
import SwiftUI

/// Full window: sidebar navigation across the five sections. Selection
/// lives in the navigation store so the popover can deep-link into it.
struct RootView: View {
  @ObservedObject var controller: EngineController
  @ObservedObject var store: NavigationStore
  var onOpenSettings: () -> Void = {}

  var body: some View {
    settingsThemed(splitView)
  }

  private var splitView: some View {
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
      .navigationSplitViewColumnWidth(
        min: 180, ideal: controller.appearance.compactSidebar ? 180 : 200)
    } detail: {
      switch store.section ?? .overview {
      case .overview:
        DashboardView(controller: controller) { section in
          store.section = section
        }
      case .processes:
        ProcessesView(controller: controller)
      case .incidents:
        IncidentsView(controller: controller)
      case .history:
        HistoryView(controller: controller)
      case .settings:
        SettingsCenterView(controller: controller)
      }
    }
    .frame(minWidth: 760, minHeight: 480)
  }

  /// Applies the appearance settings (theme, accent, density) to the whole window.
  @ViewBuilder
  private func settingsThemed<Content: View>(_ content: Content) -> some View {
    let themed = content
      .preferredColorScheme(themeScheme)
      .controlSize(densityControlSize)
    if let accent = accentColor(for: controller.appearance.accentColor) {
      themed.tint(accent)
    } else {
      themed
    }
  }

  private var themeScheme: ColorScheme? {
    switch controller.appearance.theme {
    case .light: return .light
    case .dark: return .dark
    case .auto: return nil
    }
  }

  private var densityControlSize: ControlSize {
    switch controller.appearance.density {
    case .default: return .regular
    case .compact: return .small
    case .spacious: return .large
    }
  }

  private func accentColor(for name: String) -> Color? {
    switch name {
    case "blue": return .blue
    case "purple": return .purple
    case "pink": return .pink
    case "orange": return .orange
    case "yellow": return .yellow
    case "green": return .green
    case "cyan": return .cyan
    default: return nil
    }
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
      if controller.appearance.showSidebarLabels {
        Text("Ultimate Mac Monitor")
          .font(.headline)
      }
    }
    .padding(.horizontal)
    .padding(.top, 12)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private func sidebarLabel(for section: AppSection) -> some View {
    // The badge is the live active-incident count, never a hardcoded number.
    let badge = controller.activeIncidentCount
    if controller.appearance.showSidebarLabels {
      let label = Label(section.title, systemImage: section.icon).tag(section)
      if section == .incidents, badge > 0 {
        label.badge(badge)
      } else {
        label
      }
    } else {
      let icon = Image(systemName: section.icon).tag(section).help(section.title)
      if section == .incidents, badge > 0 {
        icon.badge(badge)
      } else {
        icon
      }
    }
  }

  // MARK: Detail
}
