import Charts
import SwiftUI
import MonitoringEngine

/// Dashboard: status banner, stat cards with sparklines, then detail.
struct DashboardView: View {
  @ObservedObject var controller: EngineController

  var body: some View {
    Group {
      if let evaluation = controller.evaluation {
        let snapshot = makeDashboard(evaluation, detail: .detailed)
        List {
          Section {
            HStack(alignment: .firstTextBaseline) {
              Text(snapshot.headline)
                .font(.title2.bold())
              Spacer()
              statusPill(snapshot.monitoring)
            }
            if let detail = snapshot.monitoring.detail {
              Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            Text("System health: unknown (not assessed)")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          Section("Resources") {
            HStack(spacing: 12) {
              statCard(
                title: "CPU",
                value: controller.cpuShare,
                history: controller.cpuHistory,
                tint: .blue
              )
              statCard(
                title: "Memory",
                value: controller.memoryHistory.last?.value,
                history: controller.memoryHistory,
                tint: .green
              )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
          }
          Section("Incidents") {
            if snapshot.incidents.isEmpty {
              Text("None").foregroundStyle(.secondary)
            } else {
              ForEach(snapshot.incidents.indices, id: \.self) { index in
                let incident = snapshot.incidents[index]
                HStack {
                  Image(systemName: incident.isActive ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(incident.isActive ? .orange : .green)
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
          Section("Baselines") {
            if controller.baselineStatuses.isEmpty {
              Text("Learning…").foregroundStyle(.secondary)
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
              Text("None").foregroundStyle(.secondary)
            } else {
              ForEach(Array(controller.notices.suffix(5).enumerated()), id: \.offset) { _, notice in
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
        ProgressView("Collecting first samples…")
      }
    }
    .navigationTitle("Ultimate Mac Monitor")
    .frame(minWidth: 520, minHeight: 420)
  }

  private func statusPill(_ monitoring: MonitoringStatus) -> some View {
    let color: Color =
      switch monitoring.headline {
      case "Reduced monitoring": .orange
      case "High-detail investigation": .blue
      default: .green
      }
    return HStack(spacing: 4) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(monitoring.headline).font(.caption.bold())
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color.opacity(0.12), in: Capsule())
  }

  private func statCard(
    title: String,
    value: Double?,
    history: [(date: Date, value: Double)],
    tint: Color
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title.uppercased())
        .font(.caption.bold())
        .foregroundStyle(.secondary)
      Text(value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
        .font(.largeTitle.bold().monospacedDigit())
      Chart(history, id: \.date) { point in
        AreaMark(x: .value("Time", point.date), y: .value(title, point.value))
          .foregroundStyle(tint.gradient.opacity(0.35))
        LineMark(x: .value("Time", point.date), y: .value(title, point.value))
          .foregroundStyle(tint)
      }
      .chartYScale(domain: 0...1)
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .frame(height: 48)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
  }
}
