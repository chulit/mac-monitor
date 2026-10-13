import Combine
import Foundation
import MonitoringEngine

@MainActor
final class NavigationStore: ObservableObject {
  @Published var section: AppSection? = .overview
}
