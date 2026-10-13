import Foundation
import Testing

@testable import MonitoringEngine

@Suite("Chart domain")
struct ChartDomainTests {
  @Test("Values above unit scale return a valid range containing every value")
  func nonUnitValuesDoNotTrap() {
    // Network rates are bytes/second; the old 0...1 clamp inverted the range
    // and trapped, taking the menu-bar popover down with it.
    let domain = chartDomain(values: [2048, 4096])
    #expect(domain.lowerBound < domain.upperBound)
    #expect(domain.contains(2048))
    #expect(domain.contains(4096))
  }

  @Test("A constant reading above unit scale still yields a padded band")
  func constantLargeValueDoesNotTrap() {
    let domain = chartDomain(values: [72, 72])
    #expect(domain.lowerBound < domain.upperBound)
    #expect(domain.contains(72))
  }

  @Test("Unit-scale values stay padded and ordered")
  func unitValuesStayValid() {
    let domain = chartDomain(values: [0.1, 0.3])
    #expect(domain.lowerBound < domain.upperBound)
    #expect(domain.contains(0.1))
    #expect(domain.contains(0.3))
  }

  @Test("Empty or non-finite input falls back to the default domain")
  func degenerateInputFallsBack() {
    #expect(chartDomain(values: []) == 0...1)
    #expect(chartDomain(values: [.nan, .infinity]) == 0...1)
  }
}
