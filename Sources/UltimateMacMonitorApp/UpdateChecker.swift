import Foundation

/// Checks the GitHub releases API for a newer tag. Network failures and
/// unparseable versions surface as `.failed`/`.unknown` — never as a false
/// "up to date".
@MainActor
final class UpdateChecker: ObservableObject {
  enum State: Equatable {
    case unknown
    case checking
    case upToDate
    case available(version: String)
    case failed
  }

  @Published private(set) var state: State = .unknown

  func check() async {
    state = .checking
    do {
      let url = URL(string: "https://api.github.com/repos/chulit/mac-monitor/releases/latest")!
      let (data, _) = try await URLSession.shared.data(from: url)
      let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
      let latest = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
      if Self.isNewer(latest, than: SystemInfo.appVersion) {
        state = .available(version: release.tagName)
      } else {
        state = .upToDate
      }
    } catch {
      state = .failed
    }
  }

  /// Numeric dot-separated comparison: "0.2.0" > "0.1.0" > "0.1".
  static func isNewer(_ latest: String, than current: String) -> Bool {
    let l = latest.split(separator: ".").compactMap { Int($0) }
    let c = current.split(separator: ".").compactMap { Int($0) }
    guard !l.isEmpty, !c.isEmpty else {
      return false
    }
    for (a, b) in zip(l, c) {
      if a != b {
        return a > b
      }
    }
    return l.count > c.count
  }

  private struct GitHubRelease: Decodable {
    var tagName: String
    enum CodingKeys: String, CodingKey {
      case tagName = "tag_name"
    }
  }
}
