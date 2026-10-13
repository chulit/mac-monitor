import Foundation

/// Time windows for the overview header range picker.
///
/// The picker owns the selection; the chart tickets (overview issues 03-04)
/// consume it to size their data window. Pure value type so it stays unit
/// tested without any UI.
public enum OverviewTimeRange: String, CaseIterable, Sendable {
  case fifteenMinutes = "15m"
  case thirtyMinutes = "30m"
  case oneHour = "1h"
  case sixHours = "6h"
  case twentyFourHours = "24h"

  public static let `default`: OverviewTimeRange = .oneHour

  public var title: String {
    switch self {
    case .fifteenMinutes: return "Last 15 Minutes"
    case .thirtyMinutes: return "Last 30 Minutes"
    case .oneHour: return "Last 1 Hour"
    case .sixHours: return "Last 6 Hours"
    case .twentyFourHours: return "Last 24 Hours"
    }
  }

  public var seconds: TimeInterval {
    switch self {
    case .fifteenMinutes: return 900
    case .thirtyMinutes: return 1_800
    case .oneHour: return 3_600
    case .sixHours: return 21_600
    case .twentyFourHours: return 86_400
    }
  }
}
