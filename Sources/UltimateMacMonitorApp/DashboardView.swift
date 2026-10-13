import SwiftUI
import MonitoringEngine

/// Dashboard: status banner, stat cards with adaptive sparklines, then a
/// compact detail area. A ScrollView keeps content top-aligned instead of
/// stretching empty rows across the window.
struct DashboardView: View {
  @ObservedObject var controller: EngineController
  @State private var timeRange: OverviewTimeRange = .default

  var body: some View {
    Group {
      if let evaluation = controller.evaluation {
        let snapshot = makeDashboard(evaluation, detail: .detailed)
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            OverviewHeaderView(controller: controller, timeRange: $timeRange)
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
            detailSections(snapshot: snapshot)
          }
          .padding()
        }
      } else {
        ProgressView("Collecting first samples…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationTitle("Ultimate Mac Monitor")
  }

  @ViewBuilder
  private func detailSections(snapshot: DashboardSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      if !snapshot.incidents.isEmpty {
        detailGroup(title: "Incidents") {
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
      detailGroup(title: "Baselines") {
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
      detailGroup(title: "History storage") {
        Text("\(controller.storageUnits) samples · quota \(quotaText)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      if !controller.notices.isEmpty {
        detailGroup(title: "Notices") {
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
  }

  @ViewBuilder
  private func detailGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title.uppercased())
        .font(.caption.bold())
        .foregroundStyle(.secondary)
      content()
    }
  }

  private var quotaText: String {
    let millions = Double(controller.storageQuota) / 1_000_000
    if millions >= 1 {
      return String(format: "%.1fM", millions)
    }
    return "\(controller.storageQuota)"
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
      Sparkline(values: history, tint: tint)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
  }
}
