import Foundation

public struct SyntheticStream: Sendable {
  public enum Scenario: Sendable {
    case normal
    case withGaps
    case spike
    case sustainedPressure
  }

  public let samples: [Sample]

  public static func scenario(
    _ scenario: Scenario,
    startingAt start: Date,
    spacing: TimeInterval
  ) -> SyntheticStream {
    switch scenario {
    case .normal:
      let samples = (0..<10).map { index in
        Sample(
          timestamp: start.addingTimeInterval(TimeInterval(index) * spacing),
          availability: .available,
          value: 0.3
        )
      }
      return SyntheticStream(samples: samples)
    case .withGaps:
      let samples = (0..<10).map { index in
        let gapped = index == 3 || index == 7
        return Sample(
          timestamp: start.addingTimeInterval(TimeInterval(index) * spacing),
          availability: gapped ? .unavailable : .available,
          value: gapped ? nil : 0.3
        )
      }
      return SyntheticStream(samples: samples)
    case .spike:
      let samples = (0..<12).map { index in
        Sample(
          timestamp: start.addingTimeInterval(TimeInterval(index) * spacing),
          availability: .available,
          value: index == 5 ? 0.95 : 0.3
        )
      }
      return SyntheticStream(samples: samples)
    case .sustainedPressure:
      let critical: [Double] = [0.85, 0.9, 0.95, 0.95, 0.99, 0.95, 0.9, 0.9, 0.85, 0.85]
      let samples = (0..<22).map { index in
        let value: Double
        if index >= 5 && index <= 14 {
          value = critical[index - 5]
        } else {
          value = 0.3
        }
        return Sample(
          timestamp: start.addingTimeInterval(TimeInterval(index) * spacing),
          availability: .available,
          value: value
        )
      }
      return SyntheticStream(samples: samples)
    }
  }

  private init(samples: [Sample]) {
    self.samples = samples
  }
}
