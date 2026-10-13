import Foundation

/// The sections of the main window sidebar, in sidebar order.
///
/// Lives in the engine (not the app target) so the alias contract and the
/// section metadata are unit tested. Pure identifiers only: no SwiftUI.
public enum AppSection: String, Hashable, CaseIterable {
  case overview
  case processes
  case incidents
  case history
  case settings

  /// Backward-compatible aliases for legacy callers.
  @available(*, deprecated, renamed: "overview")
  public static var dashboard: AppSection { .overview }
  @available(*, deprecated, renamed: "incidents")
  public static var investigation: AppSection { .incidents }

  public var title: String {
    switch self {
    case .overview: return "Overview"
    case .processes: return "Processes"
    case .incidents: return "Incidents"
    case .history: return "History"
    case .settings: return "Settings"
    }
  }

  public var icon: String {
    switch self {
    case .overview: return "house.fill"
    case .processes: return "list.bullet"
    case .incidents: return "bell"
    case .history: return "clock"
    case .settings: return "gearshape"
    }
  }
}
