import AppKit
import Combine
import MonitoringEngine
import SwiftUI

/// Owns the menu-bar presence: a popover with condensed status on click.
/// Thin by agreement: it renders published controller values, nothing more.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var controller: EngineController?
  private var statusItem: NSStatusItem?
  private var cancellables = Set<AnyCancellable>()
  private let popover: NSPopover = {
    let popover = NSPopover()
    popover.behavior = .transient
    return popover
  }()

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.title = "–"
    statusItem?.button?.action = #selector(togglePopover)
    statusItem?.button?.target = self
  }

  func bind(_ controller: EngineController) {
    self.controller = controller
    controller.$evaluation
      .sink { [weak self] _ in self?.refresh() }
      .store(in: &cancellables)
  }

  private func refresh() {
    if let share = controller?.cpuShare {
      statusItem?.button?.title = "\(Int((share * 100).rounded()))%"
    } else {
      statusItem?.button?.title = "–"
    }
  }

  @objc private func togglePopover() {
    guard let button = statusItem?.button else {
      return
    }
    if popover.isShown {
      popover.performClose(nil)
      return
    }
    guard let controller else {
      return
    }
    popover.contentViewController = NSHostingController(
      rootView: PopoverView(
        controller: controller,
        onOpen: { [weak self] in self?.openMonitor() },
        onQuit: { NSApp.terminate(nil) }
      )
    )
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
  }

  @objc private func openMonitor() {
    popover.performClose(nil)
    NSApp.activate(ignoringOtherApps: true)
    for window in NSApp.windows where window.canBecomeMain {
      window.makeKeyAndOrderFront(nil)
    }
  }
}
