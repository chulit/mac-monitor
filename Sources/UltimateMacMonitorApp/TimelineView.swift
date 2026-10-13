import Charts
import SwiftUI
import MonitoringEngine

/// Investigation screen: charted metrics with incident markers above the
/// evidence detail, relevance, and the graded explanation.
struct TimelineView: View {
  @ObservedObject var controller: EngineController

  var body: some View {
    Group {
      if let timelines = controller.evaluation?.timelines, !timelines.isEmpty {
        List {
          ForEach(timelines.indices, id: \.self) { index in
            let timeline = timelines[index]
            let points = makeTimelinePoints(timeline)
            let explanation = makeExplanation(timeline)
            Section("Incident at \(timeline.incident.startedAt, style: .time)") {
              metricChart(points: points, markers: timeline.markers)
                .frame(height: 140)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
              ForEach(points, id: \.timestamp) { point in
                Text(point.tooltip)
                  .font(.caption.monospaced())
                  .foregroundStyle(point.hasUnavailableData ? .secondary : .primary)
              }
            }
            Section("Relevance") {
              if timeline.relevantProcesses.isEmpty {
                Text("No processes attributed.").foregroundStyle(.secondary)
              } else {
                ForEach(timeline.relevantProcesses, id: \.process.id) { relevance in
                  VStack(alignment: .leading) {
                    Text(relevance.process.name)
                    ForEach(relevance.reasons, id: \.self) { reason in
                      Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                  }
                }
              }
            }
            Section("Explanation") {
              ForEach(explanation.facts, id: \.self) { Text($0) }
              ForEach(explanation.hypotheses, id: \.self) {
                Text($0).italic()
              }
              ForEach(explanation.uncertainty, id: \.self) {
                Text($0).foregroundStyle(.secondary)
              }
            }
          }
        }
      } else {
        Text("No incidents recorded yet.")
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Investigation")
    .frame(minWidth: 520, minHeight: 420)
  }

  private func metricChart(points: [TimelinePoint], markers: [TimelineMarker]) -> some View {
    let metrics = Set(points.flatMap { $0.valuesByMetric.keys }).sorted()
    return Chart {
      ForEach(metrics, id: \.self) { metric in
        ForEach(points.filter { $0.valuesByMetric[metric] != nil }, id: \.timestamp) { point in
          LineMark(
            x: .value("Time", point.timestamp),
            y: .value(metric, point.valuesByMetric[metric] ?? 0),
            series: .value("Metric", metric)
          )
        }
      }
      ForEach(markers, id: \.timestamp) { marker in
        RuleMark(x: .value("Event", marker.timestamp))
          .foregroundStyle(marker.kind == .recovered ? .green : .orange)
          .annotation(position: .top, alignment: .center) {
            Text(markerLabel(marker.kind))
              .font(.caption2.bold())
              .foregroundStyle(.secondary)
          }
      }
    }
    .chartYScale(domain: 0...1)
    .chartXAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) { _ in
        AxisValueLabel(format: .dateTime.hour().minute().second(), centered: true)
      }
    }
  }

  private func markerLabel(_ kind: TimelineMarker.Kind) -> String {
    switch kind {
    case .started: return "start"
    case .peak: return "peak"
    case .recovered: return "recovered"
    }
  }
}
