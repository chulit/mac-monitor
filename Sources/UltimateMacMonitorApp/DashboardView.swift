import SwiftUI
import MonitoringEngine

/// Dashboard: status banner, stat cards with adaptive sparklines, then a
/// compact detail area. A ScrollView keeps content top-aligned instead of
/// stretching empty rows across the window.
struct DashboardView: View {
  @ObservedObject var controller: EngineController
  @State private var timeRange: OverviewTimeRange = .default
  /// Section navigation for the card links. A closure keeps the card inputs
  /// narrow instead of handing the whole navigation store down.
  var onNavigate: (AppSection) -> Void = { _ in }

  var body: some View {
    Group {
      if let evaluation = controller.evaluation {
        let snapshot = makeDashboard(evaluation, detail: .detailed)
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            OverviewHeaderView(controller: controller, timeRange: $timeRange)
            investigationCard
            metricCards
            usageTimelineCard
            bottomCards
            detailSections(snapshot: snapshot)
          }
          .padding()
          .animation(
            .spring(response: 0.45, dampingFraction: 0.85),
            value: controller.isInvestigating
          )
        }
      } else {
        ProgressView("Collecting first samples…")
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .navigationTitle("Ultimate Mac Monitor")
  }

  private var metricCards: some View {
    let investigating = controller.isInvestigating
    return HStack(spacing: 12) {
      MetricStatCard(
        title: "CPU",
        icon: "cpu",
        tint: .blue,
        valueText: percentText(controller.cpuShare),
        history: controller.cpuHistory,
        delta: investigating
          ? baselineDeviation(
            current: controller.cpuShare, baselineMean: controller.baselineMeans["cpu"])
          : nil
      )
      MetricStatCard(
        title: "Memory",
        icon: "memorychip",
        tint: .purple,
        valueText: percentText(controller.memoryHistory.last?.value),
        history: controller.memoryHistory,
        delta: investigating
          ? baselineDeviation(
            current: controller.memoryHistory.last?.value,
            baselineMean: controller.baselineMeans["memory"])
          : nil
      )
      MetricStatCard(
        title: "Disk",
        icon: "internaldrive",
        tint: .green,
        valueText: percentText(controller.diskHistory.last?.value),
        history: controller.diskHistory,
        delta: investigating
          ? baselineDeviation(
            current: controller.diskHistory.last?.value,
            baselineMean: controller.baselineMeans["disk"])
          : nil
      )
      MetricStatCard(
        title: "Network",
        icon: "wifi",
        tint: .cyan,
        valueText: controller.networkHistory.last.map { formatRate($0.value) } ?? "–",
        history: controller.networkHistory,
        delta: investigating
          ? baselineDeviation(
            current: controller.networkHistory.last?.value,
            baselineMean: controller.baselineMeans["network"])
          : nil
      )
    }
  }

  private func percentText(_ value: Double?) -> String {
    value.map { "\(Int(($0 * 100).rounded()))%" } ?? "–"
  }

  private var usageTimelineCard: some View {
    UsageTimelineCard(
      histories: [
        .cpu: controller.cpuHistory,
        .memory: controller.memoryHistory,
        .disk: controller.diskHistory,
        .network: controller.networkHistory,
      ],
      timeRange: timeRange
    )
  }

  /// The dedicated investigation card, visible only while a high-detail
  /// session runs. The spring on the container animates its entrance and exit.
  @ViewBuilder
  private var investigationCard: some View {
    if controller.isInvestigating,
      let mode = controller.evaluation?.observation?.mode,
      case .highDetail(let remaining, let limit, _) = mode
    {
      InvestigationProgressCard(
        progress: investigationProgress(
          remaining: remaining,
          limit: limit,
          incidents: controller.evaluation?.incidents ?? [],
          now: Date()
        )
      )
      .transition(.scale(scale: 0.96).combined(with: .opacity))
    }
  }

  private var bottomCards: some View {
    HStack(alignment: .top, spacing: 12) {
      RecentIncidentsCard(
        incidents: (controller.evaluation?.incidents ?? [])
          .sorted { $0.startedAt > $1.startedAt },
        timelines: controller.evaluation?.timelines ?? [],
        onSeeAll: { onNavigate(.incidents) },
        onSelectIncident: { _ in onNavigate(.incidents) }
      )
      TopProcessesCard(
        samples: controller.processes,
        onSelectProcess: { onNavigate(.processes) }
      )
    }
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
}
