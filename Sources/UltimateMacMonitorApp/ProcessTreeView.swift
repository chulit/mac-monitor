import SwiftUI
import MonitoringEngine

/// Thin process screen: search, expand, and collapse state lives in the
/// view; rows come straight from `processRows`.
struct ProcessTreeView: View {
  @ObservedObject var controller: EngineController
  @State private var query = ""
  @State private var expanded: Set<String> = []

  var body: some View {
    VStack {
      TextField("Search processes", text: $query)
        .textFieldStyle(.roundedBorder)
        .padding([.horizontal, .top])
      List {
        ForEach(processRows(controller.processes, query: query, expanded: expanded), id: \.process.id) { row in
          HStack {
            Text(row.process.name)
              .padding(.leading, CGFloat(row.depth) * 16)
            Spacer()
            Text("\(row.individualTotal, specifier: "%.2f") / \(row.subtreeTotal, specifier: "%.2f")")
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
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
    .frame(minWidth: 480, minHeight: 320)
  }
}
