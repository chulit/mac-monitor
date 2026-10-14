import AppKit

/// Builds the right-click context menu for the menu-bar status items.
/// Pure construction with no side effects: the caller supplies the target
/// and selectors, shows the menu, and handles the actions.
enum MenuBarContextMenu {
  static func make(
    target: AnyObject,
    settingsAction: Selector,
    quitAction: Selector
  ) -> NSMenu {
    let menu = NSMenu()
    let settings = NSMenuItem(
      title: "Settings…",
      action: settingsAction,
      keyEquivalent: ","
    )
    settings.target = target
    menu.addItem(settings)
    menu.addItem(.separator())
    let quit = NSMenuItem(
      title: "Quit Ultimate Mac Monitor",
      action: quitAction,
      keyEquivalent: "q"
    )
    quit.target = target
    menu.addItem(quit)
    return menu
  }
}
