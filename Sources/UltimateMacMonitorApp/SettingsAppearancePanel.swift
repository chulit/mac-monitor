import MonitoringEngine
import SwiftUI

/// Appearance panel (issue 06): theme, accent color, density, sidebar
/// options, and animations. All apply live through the controller's
/// published appearance snapshot.
struct SettingsAppearancePanel: View {
  @ObservedObject var viewModel: SettingsViewModel

  private let accents: [(name: String, color: Color?)] = [
    ("blue", .blue),
    ("purple", .purple),
    ("pink", .pink),
    ("orange", .orange),
    ("yellow", .yellow),
    ("green", .green),
    ("cyan", .cyan),
    ("multicolor", nil),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      themeCard
      accentCard
      densityCard
      sidebarCard
      animationsCard
    }
  }

  private var themeCard: some View {
    SettingsCard(
      title: "Theme",
      subtitle: "Choose your preferred appearance."
    ) {
      HStack(spacing: 8) {
        ForEach(AppTheme.allCases, id: \.self) { theme in
          Button {
            viewModel.update(\.theme, to: theme)
          } label: {
            VStack(spacing: 6) {
              themePreview(for: theme)
              HStack(spacing: 6) {
                Image(
                  systemName: viewModel.current.theme == theme
                    ? "largecircle.fill.circle" : "circle"
                )
                .foregroundStyle(
                  viewModel.current.theme == theme ? Color.accentColor : .secondary
                )
                Text(theme.title)
                  .font(.callout)
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
              viewModel.current.theme == theme
                ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05),
              in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(
                  viewModel.current.theme == theme
                    ? Color.accentColor.opacity(0.5) : Color.clear,
                  lineWidth: 1
                )
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(theme.title) theme")
        }
      }
    }
  }

  private func themePreview(for theme: AppTheme) -> some View {
    ZStack {
      switch theme {
      case .light:
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.white)
      case .dark:
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(white: 0.12))
      case .auto:
        HStack(spacing: 0) {
          Color.white
          Color(white: 0.12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
      }
      VStack(spacing: 4) {
        HStack(spacing: 3) {
          Circle().fill(Color.red).frame(width: 5, height: 5)
          Circle().fill(Color.yellow).frame(width: 5, height: 5)
          Circle().fill(Color.green).frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        RoundedRectangle(cornerRadius: 3)
          .fill(Color.gray.opacity(0.3))
          .frame(height: 8)
        RoundedRectangle(cornerRadius: 3)
          .fill(Color.gray.opacity(0.2))
          .frame(height: 8)
      }
      .padding(8)
    }
    .frame(height: 64)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
    )
  }

  private var accentCard: some View {
    SettingsCard(
      title: "Accent Color",
      subtitle: "Choose an accent color for highlights and charts."
    ) {
      HStack(spacing: 10) {
        ForEach(accents, id: \.name) { accent in
          Button {
            viewModel.update(\.accentColor, to: accent.name)
          } label: {
            ZStack {
              if let color = accent.color {
                Circle()
                  .fill(color)
                  .frame(width: 28, height: 28)
              } else {
                Circle()
                  .fill(
                    AngularGradient(
                      colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                      center: .center
                    )
                  )
                  .frame(width: 28, height: 28)
              }
              if viewModel.current.accentColor == accent.name {
                Circle()
                  .stroke(Color.primary, lineWidth: 2)
                  .frame(width: 34, height: 34)
              }
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(accent.name) accent color")
        }
      }
    }
  }

  private var densityCard: some View {
    SettingsCard(
      title: "Interface Density",
      subtitle: "Adjust spacing for a more compact or spacious layout."
    ) {
      HStack(spacing: 8) {
        ForEach(InterfaceDensity.allCases, id: \.self) { density in
          Button {
            viewModel.update(\.density, to: density)
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                  RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: density == .compact ? 6 : density == .spacious ? 12 : 9)
                }
              }
              .frame(height: 40)
              HStack(spacing: 6) {
                Image(
                  systemName: viewModel.current.density == density
                    ? "largecircle.fill.circle" : "circle"
                )
                .foregroundStyle(
                  viewModel.current.density == density ? Color.accentColor : .secondary
                )
                Text(density.title)
                  .font(.callout)
              }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              viewModel.current.density == density
                ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.05),
              in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .stroke(
                  viewModel.current.density == density
                    ? Color.accentColor.opacity(0.5) : Color.clear,
                  lineWidth: 1
                )
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("\(density.title) density")
        }
      }
    }
  }

  private var sidebarCard: some View {
    SettingsCard(
      title: "Sidebar",
      subtitle: "Customize the sidebar appearance."
    ) {
      VStack(spacing: 0) {
        SettingsToggleRow(
          icon: "sidebar.left",
          tint: .blue,
          title: "Show Sidebar Labels",
          subtitle: "Display text labels alongside icons.",
          isOn: viewModel.binding(\.showSidebarLabels)
        )
        Divider()
        SettingsToggleRow(
          icon: "list.bullet",
          tint: .gray,
          title: "Use Compact Sidebar",
          subtitle: "Reduce sidebar width.",
          isOn: viewModel.binding(\.compactSidebar)
        )
      }
    }
  }

  private var animationsCard: some View {
    SettingsCard(
      title: "Animations",
      subtitle: "Control interface animations and transitions."
    ) {
      SettingsToggleRow(
        icon: "eye.slash",
        tint: .gray,
        title: "Reduce Motion",
        subtitle: "Minimize animations for a more focused experience.",
        isOn: viewModel.binding(\.reduceMotion)
      )
    }
  }
}
