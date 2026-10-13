import AppKit
import Combine
import MonitoringEngine

/// Owns the menu-bar status item. Thin by agreement: it renders the latest
/// CPU share and offers Open/Quit, nothing more.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  var controller: EngineController?
  private var statusItem: NSStatusItem?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem?.button?.title = "–"
    let menu = NSMenu()
    let open = NSMenuItem(
      title: "Open Monitor",
      action: #selector(openMonitor),
      keyEquivalent: ""
    )
    open.target = self
    menu.addItem(open)
    menu.addItem(.separator())
    let quit = NSMenuItem(
      title: "Quit Ultimate Mac Monitor",
      action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q"
    )
    menu.addItem(quit)
    statusItem?.menu = menu
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

  @objc private func openMonitor() {
    NSApp.activate(ignoringOtherApps: true)
    for window in NSApp.windows where window.canBecomeMain {
      window.makeKeyAndOrderFront(nil)
    }
  }
}
