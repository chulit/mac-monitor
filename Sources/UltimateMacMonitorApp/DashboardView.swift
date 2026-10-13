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
          Section("Baselines") {
            if controller.baselineStatuses.isEmpty {
              Text("Learning…")
            } else {
              ForEach(controller.baselineStatuses.sorted(by: { $0.key < $1.key }), id: \.key) { metric, status in
                HStack {
                  Text(metric)
                  Spacer()
                  Text(status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          Section("History storage") {
            Text("\(controller.storageUnits) of \(controller.storageQuota) samples retained")
              .font(.caption)
          }
          Section("Notices") {
            if controller.notices.isEmpty {
              Text("None")
            } else {
              ForEach(controller.notices.suffix(5).indices, id: \.self) { index in
                let notice = Array(controller.notices.suffix(5))[index]
                VStack(alignment: .leading) {
                  Text(notice.message)
                  if let detail = notice.detail {
                    Text(detail)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
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
