import Foundation

/// Live progress of an active high-detail investigation session.
///
/// The donut shows the real session fraction (elapsed / limit). The three
/// phases narrate what the session does, with states derived from facts:
/// scanning is complete once collection runs, analysis is active for the
/// whole session, and detection completes when an incident actually started
/// inside this session. Nothing here is interpolated or fabricated.
public struct InvestigationPhase: Sendable, Equatable {
  public enum State: Sendable, Equatable {
    case completed
    case active
    case pending
  }

  public let title: String
  public let subtitle: String
  public let state: State
  public let statusText: String
  public let durationText: String
  /// Session fraction for the active phase's bar; nil otherwise.
  public let progress: Double?

  public init(
    title: String,
    subtitle: String,
    state: State,
    statusText: String,
    durationText: String,
    progress: Double? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.state = state
    self.statusText = statusText
    self.durationText = durationText
    self.progress = progress
  }
}

public struct InvestigationProgress: Sendable, Equatable {
  /// 0...1 of the session limit elapsed.
  public let fraction: Double
  /// Always exactly three phases, in tracker order.
  public let phases: [InvestigationPhase]

  public var completedCount: Int {
    phases.filter { $0.state == .completed }.count
  }

  public init(fraction: Double, phases: [InvestigationPhase]) {
    self.fraction = fraction
    self.phases = phases
  }
}

/// Builds the progress model from the live high-detail observation. The view
/// only calls this while `isInvestigating`, so a missing session never
/// renders a fabricated card.
public func investigationProgress(
  remaining: TimeInterval,
  limit: TimeInterval,
  incidents: [Incident],
  now: Date
) -> InvestigationProgress {
  let clampedLimit = max(limit, 1e-9)
  let elapsed = min(max(clampedLimit - remaining, 0), clampedLimit)
  let fraction = elapsed / clampedLimit
  let percent = Int((fraction * 100).rounded())
  let seconds = Int(elapsed.rounded())
  let sessionStart = now.addingTimeInterval(-elapsed)
  let detected = incidents.contains { $0.startedAt >= sessionStart }

  return InvestigationProgress(
    fraction: fraction,
    phases: [
      InvestigationPhase(
        title: "Scanning System Resources",
        subtitle: "Analyzing CPU, memory, disk, and network usage…",
        state: .completed,
        statusText: "Completed",
        durationText: "—"
      ),
      InvestigationPhase(
        title: "Analyzing Processes",
        subtitle: "Detecting abnormal behavior and resource usage…",
        state: .active,
        statusText: "\(percent)%",
        durationText: "\(seconds)s",
        progress: fraction
      ),
      InvestigationPhase(
        title: "Detecting Potential Issues",
        subtitle: "Running diagnostics and generating insights…",
        state: detected ? .completed : .pending,
        statusText: detected ? "Completed" : "Pending",
        durationText: "—"
      ),
    ]
  )
}
