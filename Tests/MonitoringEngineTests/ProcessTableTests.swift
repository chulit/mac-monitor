import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Process table entries")
struct ProcessTableTests {
  private var base: Date { Date(timeIntervalSince1970: 30_000) }

  private func sample(
    pid: String, name: String, parent: String?, value: Double, at date: Date? = nil
  ) -> ProcessSample {
    ProcessSample(
      timestamp: date ?? base,
      process: Process(id: pid, parent: parent, name: name),
      metric: "cpu",
      value: value
    )
  }

  private var samples: [ProcessSample] {
    [
      sample(pid: "1", name: "launchd", parent: nil, value: 0.02),
      sample(pid: "100", name: "WindowServer", parent: "1", value: 0.24),
      sample(pid: "200", name: "Google Chrome", parent: "1", value: 0.06),
      sample(pid: "201", name: "Google Chrome Helper", parent: "200", value: 0.03),
      sample(pid: "300", name: "kernel_task", parent: nil, value: 0.12),
    ]
  }

  @Test("Flat list sorts by CPU descending")
  func flatSortByCPU() {
    let entries = processTableEntries(samples: samples, sort: .cpu)
    #expect(entries.map(\.process.name) == [
      "WindowServer", "kernel_task", "Google Chrome", "Google Chrome Helper", "launchd",
    ])
    #expect(entries.allSatisfy { $0.depth == 0 })
  }

  @Test("Sort by name and PID")
  func sortByNameAndPID() {
    let byName = processTableEntries(samples: samples, sort: .name)
    #expect(byName.first?.process.name == "Google Chrome")
    let byPID = processTableEntries(samples: samples, sort: .pid)
    #expect(byPID.map(\.process.id) == ["1", "100", "200", "201", "300"])
  }

  @Test("Query filters case-insensitively and flattens the tree")
  func queryFiltering() {
    let entries = processTableEntries(samples: samples, query: "chrome", showTree: true)
    #expect(entries.map(\.process.name) == ["Google Chrome", "Google Chrome Helper"])
    #expect(entries.allSatisfy { $0.depth == 0 })
  }

  @Test("Tree hides children until expanded")
  func treeExpandCollapse() {
    let collapsed = processTableEntries(samples: samples, showTree: true, expanded: [])
    #expect(!collapsed.contains { $0.process.id == "201" })
    let chrome = collapsed.first { $0.process.id == "200" }
    #expect(chrome?.hasChildren == true)
    #expect(chrome?.isExpanded == false)

    let expanded = processTableEntries(
      samples: samples, showTree: true, expanded: ["200"]
    )
    let helper = expanded.first { $0.process.id == "201" }
    #expect(helper?.depth == 1)
    #expect(expanded.first { $0.process.id == "200" }?.isExpanded == true)
  }

  @Test("Entries carry individual shares, never subtree aggregates")
  func individualSharesOnly() {
    // Chrome (0.06) parents a helper (0.03): the entry must show 0.06,
    // not the 0.09 subtree sum.
    let entries = processTableEntries(samples: samples, showTree: true, expanded: ["200"])
    let chrome = entries.first { $0.process.id == "200" }
    #expect(chrome?.cpuShare == 0.06)
  }

  @Test("Parent names resolve, roots have none")
  func parentNames() {
    let entries = processTableEntries(samples: samples, sort: .pid)
    #expect(entries.first { $0.process.id == "100" }?.parentName == "launchd")
    #expect(entries.first { $0.process.id == "1" }?.parentName == nil)
  }

  @Test("Latest sample wins per process")
  func latestSampleWins() {
    let newer = sample(
      pid: "100", name: "WindowServer", parent: "1", value: 0.5,
      at: base.addingTimeInterval(1)
    )
    let entries = processTableEntries(samples: samples + [newer], sort: .cpu)
    #expect(entries.first?.process.id == "100")
    #expect(entries.first?.cpuShare == 0.5)
  }
}
