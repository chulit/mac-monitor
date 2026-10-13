import Combine
import Foundation

/// Deep-link target for opening the full window from the popover.
enum AppSection: String, Hashable {
  case dashboard
  case investigation
  case processes
}

@MainActor
final class NavigationStore: ObservableObject {
  @Published var section: AppSection? = .dashboard
}
