import SwiftUI
import MonitoringEngine

/// Process screen: search, expandable rows with proportion bars. Row data
/// comes from `processRows`; only query/expand state lives here.
struct ProcessTreeView: View {
  @ObservedObject var controller: EngineController
  @State private var query = ""
  @State private var expanded: Set<String> = []

  var body: some View {
    VStack(spacing: 0) {
      TextField("Search processes", text: $query)
        .textFieldStyle(.roundedBorder)
        .padding([.horizontal, .top], 12)
        .padding(.bottom, 4)
      List {
        let rows = processRows(controller.processes, query: query, expanded: expanded)
        let ceiling = rows.map(\.subtreeTotal).max() ?? 1
        ForEach(rows, id: \.process.id) { row in
          HStack(spacing: 8) {
            Image(systemName: row.hasChildren ? (row.isExpanded ? "chevron.down" : "chevron.right") : "circle.fill")
              .font(.caption2)
              .foregroundStyle(row.hasChildren ? .secondary : .quaternary)
              .frame(width: 12)
            VStack(alignment: .leading, spacing: 2) {
              Text(row.process.name)
              GeometryReader { geometry in
                RoundedRectangle(cornerRadius: 2)
                  .fill(Color.accentColor.opacity(0.55))
                  .frame(width: geometry.size.width * barFraction(row: row, ceiling: ceiling), height: 4)
              }
              .frame(height: 4)
            }
            .padding(.leading, CGFloat(row.depth) * 16)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
              Text("\(row.subtreeTotal, specifier: "%.2f")")
                .font(.body.monospacedDigit())
              Text(row.individualTotal == row.subtreeTotal ? "individual" : "individual \(row.individualTotal, specifier: "%.2f")")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .contentShape(Rectangle())
          .onTapGesture {
            if row.hasChildren {
              if expanded.contains(row.process.id) {
                expanded.remove(row.process.id)
              } else {
                expanded.insert(row.process.id)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Processes")
    .frame(minWidth: 520, minHeight: 420)
  }

  private func barFraction(row: ProcessRow, ceiling: Double) -> Double {
    guard ceiling > 0 else {
      return 0
    }
    return min(max(row.subtreeTotal / ceiling, 0.02), 1)
  }
}
