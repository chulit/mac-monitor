import MonitoringEngine
import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable {
  case general
  case monitoring
  case alerts
  case data
  case appearance
  case privacy
  case about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .general: return "General"
    case .monitoring: return "Monitoring"
    case .alerts: return "Alert & Notifications"
    case .data: return "Data & Storage"
    case .appearance: return "Appearance"
    case .privacy: return "Privacy & Security"
    case .about: return "About"
    }
  }

  var subtitle: String {
    switch self {
    case .general: return "App behavior and appearance"
    case .monitoring: return "Data collection and sampling"
    case .alerts: return "Incident notifications"
    case .data: return "History and retention"
    case .appearance: return "Theme and display"
    case .privacy: return "Permissions and data handling"
    case .about: return "Version and updates"
    }
  }

  var icon: String {
    switch self {
    case .general: return "gearshape.fill"
    case .monitoring: return "waveform.path.ecg"
    case .alerts: return "bell.fill"
    case .data: return "cylinder.split.1x2.fill"
    case .appearance: return "display"
    case .privacy: return "lock.shield.fill"
    case .about: return "info.circle.fill"
    }
  }
}

/// Two-column settings center (issue 01): category navigation on the left,
/// the selected panel on the right. Every control binds the shared
/// SettingsViewModel, which persists through the SettingsStore.
struct SettingsCenterView: View {
  @ObservedObject var controller: EngineController
  @StateObject private var viewModel: SettingsViewModel
  @State private var category: SettingsCategory = .general

  init(controller: EngineController) {
    self.controller = controller
    _viewModel = StateObject(wrappedValue: SettingsViewModel(store: controller.settings))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Settings")
          .font(.largeTitle.bold())
        Text("Configure monitoring, alerts, data retention, and app preferences.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      HStack(alignment: .top, spacing: 12) {
        categoryNav
          .frame(width: 250)
        ScrollView {
          panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .padding()
  }

  private var categoryNav: some View {
    VStack(spacing: 4) {
      ForEach(SettingsCategory.allCases) { item in
        Button {
          category = item
        } label: {
          HStack(spacing: 10) {
            Image(systemName: item.icon)
              .font(.body)
              .foregroundStyle(category == item ? Color.accentColor : .secondary)
              .frame(width: 28)
            VStack(alignment: .leading, spacing: 1) {
              Text(item.title)
                .font(.callout)
                .fontWeight(category == item ? .semibold : .regular)
              Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .background(
            category == item ? Color.accentColor.opacity(0.1) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10)
          )
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title) settings")
      }
    }
    .padding(6)
    .dashboardCardStyle()
  }

  @ViewBuilder
  private var panel: some View {
    switch category {
    case .general:
      SettingsGeneralPanel(viewModel: viewModel)
    case .monitoring:
      SettingsMonitoringPanel(viewModel: viewModel)
    case .alerts:
      SettingsAlertsPanel(viewModel: viewModel)
    case .data:
      SettingsDataPanel(viewModel: viewModel, controller: controller)
    case .appearance:
      SettingsAppearancePanel(viewModel: viewModel)
    case .privacy:
      SettingsPrivacyPanel(viewModel: viewModel, controller: controller)
    case .about:
      SettingsAboutPanel(viewModel: viewModel, controller: controller)
    }
  }
}
