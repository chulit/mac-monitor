import Foundation

public struct ObservationPolicy: Sendable, Equatable {
  public let budgetLimit: Double
  public let criticalMetrics: Set<String>
  public let normalInterval: TimeInterval
  public let reducedInterval: TimeInterval
  public let highDetailInterval: TimeInterval
  public let overBudgetEvaluationsToDegrade: Int
  public let underBudgetEvaluationsToRecover: Int
  public let maximumHighDetailDuration: TimeInterval
  public let highDetailWarningBeforeEnd: TimeInterval

  public init(
    budgetLimit: Double,
    criticalMetrics: Set<String>,
    normalInterval: TimeInterval,
    reducedInterval: TimeInterval,
    highDetailInterval: TimeInterval,
    overBudgetEvaluationsToDegrade: Int,
    underBudgetEvaluationsToRecover: Int,
    maximumHighDetailDuration: TimeInterval,
    highDetailWarningBeforeEnd: TimeInterval
  ) {
    self.budgetLimit = budgetLimit
    self.criticalMetrics = criticalMetrics
    self.normalInterval = normalInterval
    self.reducedInterval = reducedInterval
    self.highDetailInterval = highDetailInterval
    self.overBudgetEvaluationsToDegrade = overBudgetEvaluationsToDegrade
    self.underBudgetEvaluationsToRecover = underBudgetEvaluationsToRecover
    self.maximumHighDetailDuration = maximumHighDetailDuration
    self.highDetailWarningBeforeEnd = highDetailWarningBeforeEnd
  }
}

public struct ResourceUsage: Sendable, Equatable {
  public let used: Double

  public init(used: Double) {
    self.used = used
  }
}

public enum ObservationMode: Sendable, Equatable {
  case normal
  case reduced(reason: String, affectedMetrics: [String])
  case highDetail(remaining: TimeInterval, limit: TimeInterval, warning: Bool)
}

public struct Observation: Sendable, Equatable {
  public let mode: ObservationMode
  public let intervalsByMetric: [String: TimeInterval]
  public let observedIntervals: [TimeInterval]

  public init(
    mode: ObservationMode,
    intervalsByMetric: [String: TimeInterval],
    observedIntervals: [TimeInterval]
  ) {
    self.mode = mode
    self.intervalsByMetric = intervalsByMetric
    self.observedIntervals = observedIntervals
  }
}

public struct ObservationTransition: Sendable, Equatable {
  public enum State: String, Sendable, Equatable {
    case normal
    case reduced
    case highDetail
  }

  public let timestamp: Date
  public let from: State
  public let to: State
  public let reason: String
  public let affectedMetrics: [String]

  public init(
    timestamp: Date,
    from: State,
    to: State,
    reason: String,
    affectedMetrics: [String]
  ) {
    self.timestamp = timestamp
    self.from = from
    self.to = to
    self.reason = reason
    self.affectedMetrics = affectedMetrics
  }
}

struct ObservationState {
  var coarse: ObservationTransition.State = .normal
  var overBudgetStreak = 0
  var underBudgetStreak = 0
  var highDetailEndsAt: Date?
  var highDetailLimit: TimeInterval?
  var highDetailWarned = false
}
