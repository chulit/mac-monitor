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
    guard controller != nil else {
      AppLog.event("toggle aborted: no controller")
      return
    }
    // BISECT ROUND 1 (Ship-21): minimal content isolates a content-side
    // crash from a hosting/show-side one. Restore PopoverView below.
    popover.contentViewController = NSHostingController(
      rootView: Text("probe").frame(width: 200, height: 60).padding()
    )
    popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    AppLog.event("toggle shown")
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
