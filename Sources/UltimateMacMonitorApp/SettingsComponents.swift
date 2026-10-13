import MonitoringEngine
import SwiftUI

@MainActor
extension SettingsViewModel {
  /// Two-way binding for a plain settings value: reads the mirror, writes
  /// through the store. The store's change handler syncs the mirror back.
  func binding<T>(_ keyPath: WritableKeyPath<MonitorSettings, T>) -> Binding<T> {
    Binding(
      get: { self.current[keyPath: keyPath] },
      set: { self.update(keyPath, to: $0) }
    )
  }
}

/// Grouped card used by every settings panel.
struct SettingsCard<Content: View>: View {
  let title: String
  var subtitle: String? = nil
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.headline)
      if let subtitle {
        Text(subtitle)
          .font(.callout)
          .foregroundStyle(.secondary)
      }
      content
    }
    .dashboardCardStyle()
  }
}

/// Small tinted icon badge used at the start of settings rows.
struct SettingsIcon: View {
  let systemName: String
  let tint: Color

  var body: some View {
    Image(systemName: systemName)
      .foregroundStyle(tint)
      .frame(width: 32, height: 32)
      .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
      .accessibilityHidden(true)
  }
}

/// Icon + title + subtitle + trailing toggle.
struct SettingsToggleRow: View {
  let icon: String
  let tint: Color
  let title: String
  let subtitle: String
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 12) {
      SettingsIcon(systemName: icon, tint: tint)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.callout)
        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Toggle("", isOn: $isOn)
        .labelsHidden()
        .toggleStyle(.switch)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(title)
    .accessibilityValue(isOn ? "on" : "off")
  }
}

/// Icon + title + subtitle + chevron, for navigation rows.
struct SettingsLinkRow: View {
  let icon: String
  let tint: Color
  let title: String
  let subtitle: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        SettingsIcon(systemName: icon, tint: tint)
        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.callout)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
