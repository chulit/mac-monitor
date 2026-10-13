import SwiftUI
import MonitoringEngine

/// Thin dashboard: renders the dashboard view state and nothing else.
struct DashboardView: View {
  @ObservedObject var controller: EngineController

  var body: some View {
    Group {
      if let evaluation = controller.evaluation {
        let snapshot = makeDashboard(evaluation, detail: .detailed)
        List {
          Section("Status") {
            Text(snapshot.headline)
            Text(snapshot.monitoring.headline)
            if let detail = snapshot.monitoring.detail {
              Text(detail)
            }
            Text("System health: unknown (not assessed)")
          }
          Section("Incidents") {
            if snapshot.incidents.isEmpty {
              Text("None")
            } else {
              ForEach(snapshot.incidents.indices, id: \.self) { index in
                let incident = snapshot.incidents[index]
                VStack(alignment: .leading) {
                  Text(incident.isActive ? "Active incident" : "Recovered incident")
                  Text("\(incident.relevantProcessCount) relevant processes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      } else {
        Text("Collecting first samples…")
      }
    }
    .navigationTitle("Ultimate Mac Monitor")
    .frame(minWidth: 480, minHeight: 320)
  }
}
