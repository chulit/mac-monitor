import Combine
import Foundation
import MonitoringEngine

/// Owns the engine and its collectors, publishing each evaluation.
/// Views stay thin: they render `makeDashboard` and friends over the
/// published evaluation and add no logic of their own.
@MainActor
final class EngineController: ObservableObject {
  @Published private(set) var evaluation: Evaluation?
  @Published private(set) var processes: [ProcessSample] = []

  private var pipeline: Pipeline<SystemClock>
  private var host: HostCollector<SystemClock>
  private var processCollector = ProcessCollector()
  private var timer: Timer?

  init() {
    let clock = SystemClock()
    // Detection config per Ship-07 numeric decisions.
    let rule = TechnicalRule(
      threshold: 0.9,
      triggerDuration: 30,
      recoveryDuration: 30,
      cooldown: 900
    )
    pipeline = Pipeline(clock: clock, rules: [rule])
    host = HostCollector(clock: clock)
  }

  func start(interval: TimeInterval = 1.0) {
    stop()
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.tick()
      }
    }
    tick()
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  private func tick() {
    let now = Date()
    let samples = host.collect(now: now)
    let activity = processCollector.collect(now: now)
    evaluation = pipeline.evaluate(samples, processes: activity)
    processes = activity
  }
}
