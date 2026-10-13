import Foundation

public struct NotificationPolicy: Sendable, Equatable {
  public let cooldown: TimeInterval
  public let highSeverityAfter: TimeInterval

  public init(cooldown: TimeInterval, highSeverityAfter: TimeInterval) {
    self.cooldown = cooldown
    self.highSeverityAfter = highSeverityAfter
  }
}

public struct Notice: Sendable, Equatable {
  public enum Kind: String, Sendable, Equatable {
    case anomalyStarted
    case anomalyRecovered
    case observationLimited
    case observationRestored
  }

  public enum Severity: String, Sendable, Equatable {
    case standard
    case high
  }

  public let kind: Kind
  public let incidentStartedAt: Date?
  public let severity: Severity?
  public let message: String
  public let detail: String?

  public init(
    kind: Kind,
    incidentStartedAt: Date? = nil,
    severity: Severity? = nil,
    message: String,
    detail: String? = nil
  ) {
    self.kind = kind
    self.incidentStartedAt = incidentStartedAt
    self.severity = severity
    self.message = message
    self.detail = detail
  }
}

private struct IncidentKey: Hashable {
  let startedAt: Date
  let source: Incident.Source
  let metrics: [String]
}

private struct ConditionKey: Hashable {
  let source: Incident.Source
  let metrics: [String]
}

public struct Notifier {
  public let policy: NotificationPolicy
  private var startedNotified: Set<IncidentKey> = []
  private var recoveredNotified: Set<IncidentKey> = []
  private var lastRecovery: [ConditionKey: Date] = [:]
  private var lastObservation: ObservationTransition.State?

  public init(policy: NotificationPolicy) {
    self.policy = policy
  }

  public mutating func update(_ evaluation: Evaluation, now: Date) -> [Notice] {
    var notices: [Notice] = []
    for incident in evaluation.incidents.sorted(by: { $0.startedAt < $1.startedAt }) {
      let metrics = evaluation.timelines.first { $0.incident == incident }.map {
        Set($0.metricSamples.map(\.metric)).sorted()
      } ?? []
      let key = IncidentKey(startedAt: incident.startedAt, source: incident.source, metrics: metrics)
      let condition = ConditionKey(source: incident.source, metrics: metrics)
      if startedNotified.contains(key) {
        if incident.recoveredAt != nil && !recoveredNotified.contains(key) {
          recoveredNotified.insert(key)
          if let recoveredAt = incident.recoveredAt {
            lastRecovery[condition] = recoveredAt
          }
          notices.append(
            Notice(
              kind: .anomalyRecovered,
              incidentStartedAt: incident.startedAt,
              message: "Anomaly that started at \(iso(incident.startedAt)) has recovered."
            )
          )
        }
        continue
      }
      if let recoveredAt = incident.recoveredAt {
        startedNotified.insert(key)
        recoveredNotified.insert(key)
        lastRecovery[condition] = recoveredAt
        notices.append(
          Notice(
            kind: .anomalyRecovered,
            incidentStartedAt: incident.startedAt,
            message: "Anomaly that started at \(iso(incident.startedAt)) has recovered."
          )
        )
        continue
      }
      if let last = lastRecovery[condition],
        incident.startedAt.timeIntervalSince(last) < policy.cooldown
      {
        startedNotified.insert(key)
        continue
      }
      startedNotified.insert(key)
      let severity: Notice.Severity =
        now.timeIntervalSince(incident.startedAt) >= policy.highSeverityAfter ? .high : .standard
      notices.append(
        Notice(
          kind: .anomalyStarted,
          incidentStartedAt: incident.startedAt,
          severity: severity,
          message: "Anomaly started at \(iso(incident.startedAt))."
        )
      )
    }
    let coarse: ObservationTransition.State
    var limitedDetail: String?
    switch evaluation.observation?.mode {
    case .reduced(let reason, let affectedMetrics):
      coarse = .reduced
      limitedDetail = affectedMetrics.isEmpty ? reason : "\(reason) · \(affectedMetrics.sorted().joined(separator: ", "))"
    case .highDetail:
      coarse = .highDetail
    case .normal, nil:
      coarse = .normal
    }
    if let last = lastObservation {
      if coarse == .reduced && last != .reduced {
        notices.append(
          Notice(
            kind: .observationLimited,
            message: "Observation limited.",
            detail: limitedDetail
          )
        )
      } else if coarse == .normal && last == .reduced {
        notices.append(Notice(kind: .observationRestored, message: "Full observation restored."))
      }
    }
    lastObservation = coarse
    return notices
  }
}
