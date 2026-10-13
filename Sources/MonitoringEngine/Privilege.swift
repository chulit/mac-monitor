import Darwin
import Foundation

public struct MetricAssessment: Sendable, Equatable {
  public let metric: String
  public let scope: String
  public let collectibleUnprivileged: Bool
  public let evidence: String

  public init(metric: String, scope: String, collectibleUnprivileged: Bool, evidence: String) {
    self.metric = metric
    self.scope = scope
    self.collectibleUnprivileged = collectibleUnprivileged
    self.evidence = evidence
  }
}

public struct HelperVerdict: Sendable, Equatable {
  public let assessments: [MetricAssessment]
  public let helperNeeded: Bool
  public let rationale: String
  public let notes: [String]

  public init(
    assessments: [MetricAssessment],
    helperNeeded: Bool,
    rationale: String,
    notes: [String]
  ) {
    self.assessments = assessments
    self.helperNeeded = helperNeeded
    self.rationale = rationale
    self.notes = notes
  }
}

public enum PrivilegeProbe {
  public static func assess(
    systemSamples: [Sample],
    processSamples: [ProcessSample],
    taskPortsAvailable: Bool
  ) -> HelperVerdict {
    var assessments: [MetricAssessment] = []
    for metric in ["cpu", "memory"] {
      let available = systemSamples.contains {
        $0.metric == metric && $0.availability == .available
      }
      assessments.append(
        MetricAssessment(
          metric: metric,
          scope: "system",
          collectibleUnprivileged: available,
          evidence: available
            ? "collected without privileges during probe"
            : "unavailable during probe; privilege requirement undetermined"
        )
      )
    }
    let enumerated = processSamples.count
    assessments.append(
      MetricAssessment(
        metric: "cpu",
        scope: "per-process",
        collectibleUnprivileged: enumerated > 0,
        evidence: enumerated > 0
          ? "\(enumerated) processes enumerated without privileges"
          : "no processes enumerated; privilege requirement undetermined"
      )
    )
    let inconclusive = assessments.contains { !$0.collectibleUnprivileged }
    return HelperVerdict(
      assessments: assessments,
      helperNeeded: false,
      rationale: inconclusive
        ? "Probe incomplete: some metrics were unavailable; re-run before concluding. No evidence currently requires a helper."
        : "All MVP metrics collect without privileges; no helper ships.",
      notes: taskPortsAvailable
        ? [
          "Cross-process task ports are obtainable in this context; still unused — no current metric needs them."
        ]
        : [
          "Cross-process task ports are denied here; per-process task-port metrics (memory, energy) would need a helper and are out of scope."
        ]
    )
  }

  public static func crossProcessTaskPorts() -> Bool {
    var task: task_name_t = TASK_NULL
    guard task_for_pid(mach_task_self_, 1, &task) == KERN_SUCCESS else {
      return false
    }
    mach_port_deallocate(mach_task_self_, task)
    return true
  }
}
