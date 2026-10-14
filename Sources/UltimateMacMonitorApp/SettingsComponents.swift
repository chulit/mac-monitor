import MonitoringEngine
import SwiftUI

extension AccentColorName {
  /// The SwiftUI color for this accent, or nil for multicolor (system default).
  var swiftUIColor: Color? {
    switch self {
    case .blue: return .blue
    case .purple: return .purple
    case .pink: return .pink
    case .orange: return .orange
    case .yellow: return .yellow
    case .green: return .green
    case .cyan: return .cyan
    case .multicolor: return nil
    }
  }
}

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

/// Selectable option box (radio circle + title + subtitle), shared by the
/// monitoring mode, retention, theme, and density pickers. An optional
/// preview renders above the radio row (theme/density thumbnails).
struct SettingsOptionBox<Preview: View>: View {
  let title: String
  let subtitle: String?
  let detail: String?
  let selected: Bool
  let action: () -> Void
  @ViewBuilder let preview: () -> Preview

  init(
    title: String,
    subtitle: String? = nil,
    detail: String? = nil,
    selected: Bool,
    action: @escaping () -> Void,
    @ViewBuilder preview: @escaping () -> Preview = { EmptyView() }
  ) {
    self.title = title
    self.subtitle = subtitle
    self.detail = detail
    self.selected = selected
    self.action = action
    self.preview = preview
  }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 6) {
        preview()
        HStack(spacing: 6) {
          Image(systemName: selected ? "largecircle.fill.circle" : "circle")
            .foregroundStyle(selected ? Color.accentColor : .secondary)
          Text(title)
            .font(.callout.bold())
        }
        if let subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if let detail {
          Text(detail)
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        selected ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05),
        in: RoundedRectangle(cornerRadius: 10)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(
            selected ? Color.accentColor.opacity(0.5) : Color.clear,
            lineWidth: 1
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(title)
  }
}
