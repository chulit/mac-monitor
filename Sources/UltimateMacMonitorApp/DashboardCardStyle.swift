import SwiftUI

/// Shared dashboard card styling: 14pt rounded corners, subtle border, and a
/// soft elevation shadow. Extracted as a modifier (per the SwiftUI skills) so
/// every overview card renders identically.
struct DashboardCardStyle: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gray.opacity(0.15)))
      .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
  }
}

extension View {
  func dashboardCardStyle() -> some View {
    modifier(DashboardCardStyle())
  }
}
