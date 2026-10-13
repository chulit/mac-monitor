import AppKit
import MonitoringEngine
import SwiftUI

/// About panel (issue 07): real version, update checker, links, changelog,
/// and system info. Nothing here is hardcoded except the changelog, which
/// is written from the repository's actual history.
struct SettingsAboutPanel: View {
  @ObservedObject var viewModel: SettingsViewModel
  @ObservedObject var controller: EngineController
  @ObservedObject private var updater: UpdateChecker

  init(viewModel: SettingsViewModel, controller: EngineController) {
    self.viewModel = viewModel
    self.controller = controller
    _updater = ObservedObject(wrappedValue: controller.updater)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      headerCard
      whatsNewCard
      HStack(alignment: .top, spacing: 12) {
        linksCard
          .frame(maxWidth: .infinity)
        systemInfoCard
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var headerCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 14) {
        AppLogo(size: 64)
        VStack(alignment: .leading, spacing: 4) {
          Text("Ultimate Mac Monitor")
            .font(.title3.bold())
          HStack(spacing: 8) {
            Text("Version \(SystemInfo.appVersion) (\(SystemInfo.appBuild))")
              .font(.callout)
              .foregroundStyle(.secondary)
            updateBadge
          }
          Text("A lightweight and powerful macOS monitor for real-time system insights.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
      HStack(spacing: 8) {
        Button {
          Task {
            await updater.check()
          }
        } label: {
          Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            .font(.callout)
        }
        .buttonStyle(.borderedProminent)
        .disabled(updater.state == .checking)
        Button {
          NSWorkspace.shared.open(SystemInfo.repositoryURL)
        } label: {
          Label("View on GitHub", systemImage: "arrow.up.right")
            .font(.callout)
        }
        .buttonStyle(.bordered)
      }
    }
    .dashboardCardStyle()
  }

  @ViewBuilder
  private var updateBadge: some View {
    switch updater.state {
    case .unknown:
      EmptyView()
    case .checking:
      HStack(spacing: 4) {
        ProgressView()
          .controlSize(.small)
        Text("Checking…")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    case .upToDate:
      HStack(spacing: 4) {
        Circle()
          .fill(Color.green)
          .frame(width: 8, height: 8)
        Text("Up to date")
          .font(.caption)
          .foregroundStyle(.green)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    case .available(let version):
      Button {
        NSWorkspace.shared.open(SystemInfo.releasesURL)
      } label: {
        Text("Update available: \(version)")
          .font(.caption.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
      }
      .buttonStyle(.plain)
    case .failed:
      Text("Couldn't check for updates")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var whatsNewCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("What's New")
          .font(.headline)
        Spacer()
        Button("View All Updates >") {
          NSWorkspace.shared.open(SystemInfo.releasesURL)
        }
        .buttonStyle(.link)
        .font(.callout)
      }
      changelogEntry(
        version: "v0.1.0",
        date: "In development",
        items: [
          "App Utama modules: Overview, Processes, Incidents, History, and Settings.",
          "Retention-backed history with per-module pull requests.",
          "Incident package export and share workflow.",
          "Live settings: alert thresholds, sampling cadences, retention, and appearance.",
        ],
        current: true
      )
    }
    .dashboardCardStyle()
  }

  private func changelogEntry(
    version: String, date: String, items: [String], current: Bool
  ) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Circle()
            .fill(current ? Color.accentColor : Color.secondary)
            .frame(width: 8, height: 8)
          Text(version)
            .font(.callout.bold())
        }
        Text(date)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 14)
      }
      .frame(width: 130, alignment: .leading)
      VStack(alignment: .leading, spacing: 2) {
        ForEach(items, id: \.self) { item in
          HStack(alignment: .top, spacing: 6) {
            Text("•")
              .foregroundStyle(.secondary)
            Text(item)
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .padding(.vertical, 4)
  }

  private var linksCard: some View {
    SettingsCard(title: "Links") {
      VStack(spacing: 0) {
        SettingsLinkRow(
          icon: "book", tint: .blue,
          title: "Documentation",
          subtitle: "Read guides and learn more.",
          action: { NSWorkspace.shared.open(SystemInfo.repositoryURL) }
        )
        Divider()
        SettingsLinkRow(
          icon: "chevron.left.forwardslash.chevron.right", tint: .purple,
          title: "GitHub Repository",
          subtitle: "View source code and contribute.",
          action: { NSWorkspace.shared.open(SystemInfo.repositoryURL) }
        )
        Divider()
        SettingsLinkRow(
          icon: "exclamationmark.bubble", tint: .orange,
          title: "Report an Issue",
          subtitle: "Help us improve.",
          action: { NSWorkspace.shared.open(SystemInfo.newIssueURL) }
        )
        Divider()
        SettingsLinkRow(
          icon: "heart.fill", tint: .red,
          title: "Give a Star",
          subtitle: "Support the project on GitHub.",
          action: { NSWorkspace.shared.open(SystemInfo.repositoryURL) }
        )
      }
    }
  }

  private var systemInfoCard: some View {
    SettingsCard(title: "System Info") {
      VStack(spacing: 0) {
        systemInfoRow(icon: "display", label: "macOS", value: SystemInfo.macOSVersion)
        Divider()
        systemInfoRow(icon: "cpu", label: "Chip", value: SystemInfo.chipName)
        Divider()
        systemInfoRow(icon: "memorychip", label: "Memory", value: SystemInfo.memoryGB)
        Divider()
        systemInfoRow(icon: "laptopcomputer", label: "Model", value: SystemInfo.modelID)
      }
    }
  }

  private func systemInfoRow(icon: String, label: String, value: String) -> some View {
    HStack(spacing: 10) {
      SettingsIcon(systemName: icon, tint: .secondary)
      Text(label)
        .font(.callout)
      Spacer()
      Text(value)
        .font(.callout)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .padding(.vertical, 6)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }
}
