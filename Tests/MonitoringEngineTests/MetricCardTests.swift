import Testing

@testable import MonitoringEngine

@Suite("Metric card engine math")
struct MetricCardTests {
  @Test("Fewer than two points yield no segments")
  func tooFewPointsYieldNothing() {
    #expect(smoothCurveSegments(through: []) == [])
    #expect(smoothCurveSegments(through: [CurvePoint(x: 0, y: 0)]) == [])
  }

  @Test("Two points yield one segment through both")
  func twoPointsYieldOneSegment() throws {
    let segments = smoothCurveSegments(
      through: [CurvePoint(x: 0, y: 0), CurvePoint(x: 10, y: 5)]
    )
    #expect(segments.count == 1)
    let segment = try #require(segments.first)
    #expect(segment.start == CurvePoint(x: 0, y: 0))
    #expect(segment.end == CurvePoint(x: 10, y: 5))
  }

  @Test("Collinear points keep control points on the line")
  func collinearPointsStayCollinear() throws {
    let points = (0..<5).map { CurvePoint(x: Double($0) * 10, y: 3) }
    let segments = smoothCurveSegments(through: points)
    #expect(segments.count == 4)
    for segment in segments {
      #expect(segment.control1.y == 3)
      #expect(segment.control2.y == 3)
    }
  }

  @Test("Segments chain through every input point")
  func segmentsChainThroughInputs() {
    let points = [
      CurvePoint(x: 0, y: 0),
      CurvePoint(x: 10, y: 8),
      CurvePoint(x: 20, y: 2),
      CurvePoint(x: 30, y: 6),
    ]
    let segments = smoothCurveSegments(through: points)
    #expect(segments.count == 3)
    #expect(segments.first?.start == points.first)
    #expect(segments.last?.end == points.last)
    for (segment, next) in zip(segments, segments.dropFirst()) {
      #expect(segment.end == next.start)
    }
  }

  @Test("Baseline deviation is the relative distance from the mean")
  func baselineDeviationMath() throws {
    let up = try #require(baselineDeviation(current: 0.62, baselineMean: 0.5))
    #expect(abs(up - 0.24) < 1e-9)
    let down = try #require(baselineDeviation(current: 0.4, baselineMean: 0.5))
    #expect(abs(down - (-0.2)) < 1e-9)
    #expect(baselineDeviation(current: 0.5, baselineMean: 0.5) == 0)
  }

  @Test("Baseline deviation is nil without a usable baseline")
  func baselineDeviationNilCases() {
    #expect(baselineDeviation(current: nil, baselineMean: 0.5) == nil)
    #expect(baselineDeviation(current: 0.6, baselineMean: nil) == nil)
    #expect(baselineDeviation(current: 0.6, baselineMean: 0) == nil)
    #expect(baselineDeviation(current: 0.6, baselineMean: -0.5) == nil)
    #expect(baselineDeviation(current: .nan, baselineMean: 0.5) == nil)
  }
}
