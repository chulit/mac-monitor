import Testing

@testable import MonitoringEngine

@Suite("App section navigation")
struct AppSectionTests {
  @Test("Legacy aliases resolve to the new sections")
  func legacyAliasesResolve() {
    #expect(AppSection.dashboard == .overview)
    #expect(AppSection.investigation == .incidents)
  }

  @Test("All five sections exist in sidebar order")
  func allCasesInSidebarOrder() {
    #expect(AppSection.allCases == [.overview, .processes, .incidents, .history, .settings])
  }

  @Test("Every section has a title and an icon")
  func everySectionHasTitleAndIcon() {
    for section in AppSection.allCases {
      #expect(!section.title.isEmpty, "missing title for \(section)")
      #expect(!section.icon.isEmpty, "missing icon for \(section)")
    }
  }

  @Test("Titles match the design sidebar labels")
  func titlesMatchDesign() {
    #expect(AppSection.overview.title == "Overview")
    #expect(AppSection.processes.title == "Processes")
    #expect(AppSection.incidents.title == "Incidents")
    #expect(AppSection.history.title == "History")
    #expect(AppSection.settings.title == "Settings")
  }
}
