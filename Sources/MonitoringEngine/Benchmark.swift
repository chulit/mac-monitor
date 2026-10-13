import Darwin
import Foundation

public struct BenchmarkWorkload: Sendable {
  public let name: String
  public let batches: [BenchmarkBatch]
  public let repetitions: Int

  public init(name: String, batches: [BenchmarkBatch], repetitions: Int) {
    self.name = name
    self.batches = batches
    self.repetitions = repetitions
  }
}

public struct BenchmarkBatch: Sendable {
  public let samples: [Sample]
  public let processes: [ProcessSample]
  public let usage: ResourceUsage?

  public init(samples: [Sample], processes: [ProcessSample], usage: ResourceUsage?) {
    self.samples = samples
    self.processes = processes
    self.usage = usage
  }
}

public struct BenchmarkBudget: Sendable, Equatable {
  public let maxMeanWallSeconds: Double?
  public let maxMeanCPUNanos: UInt64?
  public let maxResidentGrowthBytes: Int64?
  public let maxBlocksOut: Int64?

  public init(
    maxMeanWallSeconds: Double? = nil,
    maxMeanCPUNanos: UInt64? = nil,
    maxResidentGrowthBytes: Int64? = nil,
    maxBlocksOut: Int64? = nil
  ) {
    self.maxMeanWallSeconds = maxMeanWallSeconds
    self.maxMeanCPUNanos = maxMeanCPUNanos
    self.maxResidentGrowthBytes = maxResidentGrowthBytes
    self.maxBlocksOut = maxBlocksOut
  }
}

public struct ObservedCost: Sendable, Equatable {
  public let meanWallSeconds: Double
  public let maxWallSeconds: Double
  public let meanCPUNanos: UInt64
  public let maxCPUNanos: UInt64
  public let residentGrowthBytes: Int64
  public let blocksOut: Int64

  public init(
    meanWallSeconds: Double,
    maxWallSeconds: Double,
    meanCPUNanos: UInt64,
    maxCPUNanos: UInt64,
    residentGrowthBytes: Int64,
    blocksOut: Int64
  ) {
    self.meanWallSeconds = meanWallSeconds
    self.maxWallSeconds = maxWallSeconds
    self.meanCPUNanos = meanCPUNanos
    self.maxCPUNanos = maxCPUNanos
    self.residentGrowthBytes = residentGrowthBytes
    self.blocksOut = blocksOut
  }
}

public enum BenchmarkVerdict: Sendable, Equatable {
  case pass
  case fail(reasons: [String])
  case unmeasured
}

public func judge(_ observed: ObservedCost, against budget: BenchmarkBudget?) -> BenchmarkVerdict {
  guard let budget else {
    return .unmeasured
  }
  var reasons: [String] = []
  if let cap = budget.maxMeanWallSeconds, observed.meanWallSeconds > cap {
    reasons.append("mean wall \(observed.meanWallSeconds)s exceeds budget \(cap)s")
  }
  if let cap = budget.maxMeanCPUNanos, observed.meanCPUNanos > cap {
    reasons.append("mean CPU \(observed.meanCPUNanos)ns exceeds budget \(cap)ns")
  }
  if let cap = budget.maxResidentGrowthBytes, observed.residentGrowthBytes > cap {
    reasons.append("resident growth \(observed.residentGrowthBytes)B exceeds budget \(cap)B")
  }
  if let cap = budget.maxBlocksOut, observed.blocksOut > cap {
    reasons.append("block output \(observed.blocksOut) exceeds budget \(cap)")
  }
  return reasons.isEmpty ? .pass : .fail(reasons: reasons)
}

public struct WorkloadResult: Sendable, Equatable {
  public let workloadName: String
  public let evaluations: Int
  public let totalSamples: Int
  public let observed: ObservedCost
  public let verdict: BenchmarkVerdict

  public var meanWallSeconds: Double { observed.meanWallSeconds }

  public init(
    workloadName: String,
    evaluations: Int,
    totalSamples: Int,
    observed: ObservedCost,
    verdict: BenchmarkVerdict
  ) {
    self.workloadName = workloadName
    self.evaluations = evaluations
    self.totalSamples = totalSamples
    self.observed = observed
    self.verdict = verdict
  }
}

public struct BenchmarkReport: Sendable, Equatable {
  public let results: [WorkloadResult]

  public init(results: [WorkloadResult]) {
    self.results = results
  }
}

public enum Benchmark {
  /// In-process energy measurement is not available on macOS without
  /// privileges or external tooling. Energy gates require powermetrics
  /// runs outside this harness; this flag keeps that gap visible.
  public static let energyMeasured = false

  public static func run(
    workloads: [BenchmarkWorkload],
    budgets: [String: BenchmarkBudget],
    measure: (BenchmarkBatch) -> Evaluation
  ) -> BenchmarkReport {
    BenchmarkReport(
      results: workloads.map { workload in
        var wallTotal = 0.0
        var wallMax = 0.0
        var cpuTotal: UInt64 = 0
        var cpuMax: UInt64 = 0
        var samples = 0
        var evaluations = 0
        let residentBefore = residentBytes()
        let blocksBefore = outputBlocks()
        for _ in 0..<workload.repetitions {
          for batch in workload.batches {
            let wallStart = Date()
            let cpuStart = processCPUNanos()
            _ = measure(batch)
            let cpuElapsed = processCPUNanos() &- cpuStart
            let wallElapsed = Date().timeIntervalSince(wallStart)
            wallTotal += wallElapsed
            wallMax = max(wallMax, wallElapsed)
            cpuTotal &+= cpuElapsed
            cpuMax = max(cpuMax, cpuElapsed)
            samples += batch.samples.count
            evaluations += 1
          }
        }
        let observed = ObservedCost(
          meanWallSeconds: evaluations > 0 ? wallTotal / Double(evaluations) : 0,
          maxWallSeconds: wallMax,
          meanCPUNanos: evaluations > 0 ? cpuTotal / UInt64(evaluations) : 0,
          maxCPUNanos: cpuMax,
          residentGrowthBytes: Int64(residentBytes()) - Int64(residentBefore),
          blocksOut: outputBlocks() &- blocksBefore
        )
        return WorkloadResult(
          workloadName: workload.name,
          evaluations: evaluations,
          totalSamples: samples,
          observed: observed,
          verdict: judge(observed, against: budgets[workload.name])
        )
      }
    )
  }

  private static func processCPUNanos() -> UInt64 {
    clock_gettime_nsec_np(CLOCK_PROCESS_CPUTIME_ID)
  }

  private static func residentBytes() -> UInt64 {
    var info = task_basic_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_basic_info_data_t>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else {
      return 0
    }
    return UInt64(info.resident_size)
  }

  private static func outputBlocks() -> Int64 {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
      return 0
    }
    return Int64(usage.ru_oublock)
  }
}
