import SwiftUI
import MonitoringEngine

/// Thin investigation screen: renders timeline points, relevance, and the
/// evidence-graded explanation straight from timeline view state.
struct TimelineView: View {
  @ObservedObject var controller: EngineController

  var body: some View {
    Group {
      if let timelines = controller.evaluation?.timelines, !timelines.isEmpty {
        List {
          ForEach(timelines.indices, id: \.self) { index in
            let timeline = timelines[index]
            let explanation = makeExplanation(timeline)
            Section("Incident at \(timeline.incident.startedAt, style: .time)") {
              ForEach(makeTimelinePoints(timeline), id: \.timestamp) { point in
                Text(point.tooltip)
                  .font(.caption.monospaced())
              }
            }
            Section("Relevance") {
              if timeline.relevantProcesses.isEmpty {
                Text("No processes attributed.")
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
      }
    }
    .navigationTitle("Investigation")
    .frame(minWidth: 480, minHeight: 320)
  }
}
