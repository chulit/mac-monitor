import AppKit
import Combine
import MonitoringEngine
import SwiftUI

/// Owns the menu-bar presence: one status item per available metric plus a
/// popover with the condensed status. Thin by agreement: it renders
/// published controller values, nothing more.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var controller: EngineController?
  let navigation = NavigationStore()
  private var statusItems: [NSStatusItem] = []
  private var cancellables = Set<AnyCancellable>()
  private var settingsWindow: NSWindow?
  private let popover: NSPopover = {
    let popover = NSPopover()
    popover.behavior = .transient
    return popover
  }()

  func applicationDidFinishLaunching(_ notification: Notification) {
    AppLog.event("launch")
    statusItems = (0..<5).map { _ in
      let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
      item.button?.title = "–"
      item.button?.action = #selector(togglePopover(_:))
      item.button?.target = self
      return item
    }
    statusItems.first?.button?.image = NSImage(
      systemSymbolName: "thermometer",
      accessibilityDescription: "Temperature"
    )
  }

  func bind(_ controller: EngineController) {
    self.controller = controller
    AppLog.event("bind")
    controller.$evaluation
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)
  }

  private func refresh() {
    guard !statusItems.isEmpty else {
      return
    }
    let texts = [
      temperatureText(),
      percentText(controller?.cpuShare),
      percentText(controller?.memoryHistory.last?.value),
      percentText(controller?.diskHistory.last?.value),
      controller.map { formatRate($0.networkHistory.last?.value ?? -1) },
    ]
    for (item, text) in zip(statusItems, texts) {
      item.button?.title = text ?? "–"
    }
  }

  private func temperatureText() -> String? {
    guard controller?.temperatureFresh == true,
      let value = controller?.temperatureHistory.last?.value
    else {
      return nil
    }
    return "\(Int(value.rounded()))°"
  }

  private func percentText(_ value: Double?) -> String? {
    value.map { "\(Int(($0 * 100).rounded()))%" }
  }

  @objc private func togglePopover(_ sender: NSStatusBarButton) {
    AppLog.event("toggle isShown=\(popover.isShown)")
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    guard let controller else {
      AppLog.event("toggle aborted: no controller")
      return
    }
    popover.contentViewController = NSHostingController(
      rootView: PopoverView(
        controller: controller,
        openSection: { [weak self] section in self?.openMonitor(section: section) },
        onOpenSettings: { [weak self] in self?.openSettings() },
        onQuit: {
          AppLog.event("quit requested")
          NSApp.terminate(nil)
        }
      )
    )
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    AppLog.event("toggle shown")
  }

  /// Opens the settings window behind the gear button (issue 19) and the
  /// sidebar Settings row (overview issue 01). The window is created once
  /// and reused so its controls stay bound to the same store the collection
  /// timer reads.
  func openSettings() {
    guard let settings = controller?.settings else {
      AppLog.event("openSettings aborted: no controller")
      return
    }
    AppLog.event("openSettings")
    popover.performClose(nil)
    if settingsWindow == nil {
      let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
      )
      window.title = "Settings"
      window.contentViewController = NSHostingController(
        rootView: SettingsView(viewModel: SettingsViewModel(store: settings))
      )
      window.center()
      settingsWindow = window
    }
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow?.makeKeyAndOrderFront(nil)
  }

  private func openMonitor(section: AppSection) {
    popover.performClose(nil)
    navigation.section = section
    NSApp.activate(ignoringOtherApps: true)
    for window in NSApp.windows where window.canBecomeMain {
      window.makeKeyAndOrderFront(nil)
    }
  }
}
