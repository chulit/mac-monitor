import CryptoKit
import Foundation

public enum ArchiveError: Sendable, Equatable, Error {
  case malformed
  case checksumMismatch
  case unsupportedSchemaVersion(Int)
  case duplicate(String)
  case unknownPackage(String)
}

public struct PackageManifest: Sendable, Equatable, Codable {
  public let id: String
  public let exportedAt: Date
  public let schemaVersion: Int
  public let incidentStart: Date
  public let incidentEnd: Date?
  public let sampleCount: Int

  public init(
    id: String,
    exportedAt: Date,
    schemaVersion: Int,
    incidentStart: Date,
    incidentEnd: Date?,
    sampleCount: Int
  ) {
    self.id = id
    self.exportedAt = exportedAt
    self.schemaVersion = schemaVersion
    self.incidentStart = incidentStart
    self.incidentEnd = incidentEnd
    self.sampleCount = sampleCount
  }
}

public struct PackageContent: Sendable, Equatable, Codable {
  public let schemaVersion: Int
  public let manifest: PackageManifest
  public let incident: Incident
  public let metricSamples: [Sample]
  public let gaps: [Gap]
  public let markers: [TimelineMarker]
  public let relevantProcesses: [ProcessRelevance]
  public let observationTransitions: [ObservationTransition]
  public let summaries: [SampleSummary]
  public let ruleVersion: String?
  public let baselineVersion: String?
  public let processNamesRedacted: Bool

  public init(
    schemaVersion: Int,
    manifest: PackageManifest,
    incident: Incident,
    metricSamples: [Sample],
    gaps: [Gap],
    markers: [TimelineMarker],
    relevantProcesses: [ProcessRelevance],
    observationTransitions: [ObservationTransition],
    summaries: [SampleSummary],
    ruleVersion: String?,
    baselineVersion: String?,
    processNamesRedacted: Bool
  ) {
    self.schemaVersion = schemaVersion
    self.manifest = manifest
    self.incident = incident
    self.metricSamples = metricSamples
    self.gaps = gaps
    self.markers = markers
    self.relevantProcesses = relevantProcesses
    self.observationTransitions = observationTransitions
    self.summaries = summaries
    self.ruleVersion = ruleVersion
    self.baselineVersion = baselineVersion
    self.processNamesRedacted = processNamesRedacted
  }
}

public struct IncidentPackage: Sendable, Equatable, Codable {
  public static let currentSchemaVersion = 1

  public let content: PackageContent
  public let checksum: String

  public init(content: PackageContent, checksum: String) {
    self.content = content
    self.checksum = checksum
  }

  public var schemaVersion: Int { content.schemaVersion }
  public var manifest: PackageManifest { content.manifest }
  public var incident: Incident { content.incident }
  public var metricSamples: [Sample] { content.metricSamples }
  public var gaps: [Gap] { content.gaps }
  public var markers: [TimelineMarker] { content.markers }
  public var relevantProcesses: [ProcessRelevance] { content.relevantProcesses }
  public var observationTransitions: [ObservationTransition] { content.observationTransitions }
  public var summaries: [SampleSummary] { content.summaries }
  public var ruleVersion: String? { content.ruleVersion }
  public var baselineVersion: String? { content.baselineVersion }
  public var processNamesRedacted: Bool { content.processNamesRedacted }

  public func encoded() throws -> Data {
    try IncidentArchive.encoder().encode(self)
  }
}

public struct PackagePreview: Sendable, Equatable {
  public let manifest: PackageManifest
  public let sampleCount: Int
  public let summaryCount: Int
  public let ruleVersion: String?
  public let baselineVersion: String?
  public let processNamesRedacted: Bool
  public let migratedFrom: Int?
}

/// Frozen schema for packages written before observation transitions and
/// name redaction existed. Kept so old archives stay readable; new code
/// never writes this shape.
public struct LegacyPackageContent: Sendable, Equatable, Codable {
  public let schemaVersion: Int
  public let manifest: PackageManifest
  public let incident: Incident
  public let metricSamples: [Sample]
  public let gaps: [Gap]
  public let markers: [TimelineMarker]
  public let relevantProcesses: [ProcessRelevance]
  public let summaries: [SampleSummary]
  public let ruleVersion: String?
  public let baselineVersion: String?

  public init(
    schemaVersion: Int,
    manifest: PackageManifest,
    incident: Incident,
    metricSamples: [Sample],
    gaps: [Gap],
    markers: [TimelineMarker],
    relevantProcesses: [ProcessRelevance],
    summaries: [SampleSummary],
    ruleVersion: String?,
    baselineVersion: String?
  ) {
    self.schemaVersion = schemaVersion
    self.manifest = manifest
    self.incident = incident
    self.metricSamples = metricSamples
    self.gaps = gaps
    self.markers = markers
    self.relevantProcesses = relevantProcesses
    self.summaries = summaries
    self.ruleVersion = ruleVersion
    self.baselineVersion = baselineVersion
  }
}

public struct LegacyPackage: Sendable, Equatable, Codable {
  public let content: LegacyPackageContent
  public let checksum: String

  public init(content: LegacyPackageContent) throws {
    self.content = content
    self.checksum = try IncidentArchive.checksum(for: content)
  }

  public func encoded() throws -> Data {
    try IncidentArchive.encoder().encode(self)
  }
}

public struct Reanalysis: Sendable, Equatable, Codable {  public let label: String
  public let incidents: [Incident]
  public let algorithmVersion: String
  public let recordedAt: Date

  public init(incidents: [Incident], algorithmVersion: String, recordedAt: Date) {
    self.label = "re-analysis"
    self.incidents = incidents
    self.algorithmVersion = algorithmVersion
    self.recordedAt = recordedAt
  }
}

public struct ImportedArchive: Sendable, Equatable {
  public let package: IncidentPackage
  public let migratedFrom: Int?
  public var reanalyses: [Reanalysis]

  public init(package: IncidentPackage, migratedFrom: Int? = nil, reanalyses: [Reanalysis] = []) {
    self.package = package
    self.migratedFrom = migratedFrom
    self.reanalyses = reanalyses
  }
}

extension Incident.Source: Codable {
  private enum CodingKeys: String, CodingKey {
    case kind
    case version
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let kind = try container.decode(String.self, forKey: .kind)
    let version = try container.decode(String.self, forKey: .version)
    switch kind {
    case "rule":
      self = .rule(version: version)
    case "baseline":
      self = .baseline(version: version)
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "unknown incident source"
        )
      )
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .rule(let version):
      try container.encode("rule", forKey: .kind)
      try container.encode(version, forKey: .version)
    case .baseline(let version):
      try container.encode("baseline", forKey: .kind)
      try container.encode(version, forKey: .version)
    }
  }
}

public final class IncidentArchive {
  public private(set) var stored: [ImportedArchive] = []

  public init() {}

  public func export(
    _ timeline: IncidentTimeline,
    summaries: [SampleSummary],
    redactProcessNames: Bool,
    now: Date
  ) throws -> IncidentPackage {
    let relevance: [ProcessRelevance]
    if redactProcessNames {
      let names = timeline.relevantProcesses.map(\.process.name).sorted { $0.count > $1.count }
      relevance = timeline.relevantProcesses.map { entry in
        let reasons = entry.reasons.map { reason in
          names.reduce(reason) { $0.replacingOccurrences(of: $1, with: "redacted") }
        }
        return ProcessRelevance(
          process: Process(id: entry.process.id, parent: entry.process.parent, name: "redacted"),
          contribution: entry.contribution,
          reasons: reasons
        )
      }
    } else {
      relevance = timeline.relevantProcesses
    }
    let content = PackageContent(
      schemaVersion: IncidentPackage.currentSchemaVersion,
      manifest: PackageManifest(
        id: UUID().uuidString,
        exportedAt: now,
        schemaVersion: IncidentPackage.currentSchemaVersion,
        incidentStart: timeline.incident.startedAt,
        incidentEnd: timeline.incident.recoveredAt,
        sampleCount: timeline.metricSamples.count
      ),
      incident: timeline.incident,
      metricSamples: timeline.metricSamples,
      gaps: timeline.gaps,
      markers: timeline.markers,
      relevantProcesses: relevance,
      observationTransitions: timeline.observationTransitions,
      summaries: summaries,
      ruleVersion: timeline.ruleVersion,
      baselineVersion: timeline.baselineVersion,
      processNamesRedacted: redactProcessNames
    )
    return IncidentPackage(content: content, checksum: try Self.checksum(for: content))
  }

  public func preview(_ data: Data) throws -> PackagePreview {
    let imported = try verifiedPackage(from: data)
    let package = imported.package
    return PackagePreview(
      manifest: package.manifest,
      sampleCount: package.manifest.sampleCount,
      summaryCount: package.summaries.count,
      ruleVersion: package.ruleVersion,
      baselineVersion: package.baselineVersion,
      processNamesRedacted: package.processNamesRedacted,
      migratedFrom: imported.migratedFrom
    )
  }

  @discardableResult
  public func open(_ data: Data) throws -> ImportedArchive {
    let imported = try verifiedPackage(from: data)
    guard !stored.contains(where: { $0.package.manifest.id == imported.package.manifest.id }) else {
      throw ArchiveError.duplicate(imported.package.manifest.id)
    }
    stored.append(imported)
    return imported
  }

  public func recordReanalysis(
    packageID: String,
    incidents: [Incident],
    algorithmVersion: String,
    at recordedAt: Date
  ) throws {
    guard let index = stored.firstIndex(where: { $0.package.manifest.id == packageID }) else {
      throw ArchiveError.unknownPackage(packageID)
    }
    stored[index].reanalyses.append(
      Reanalysis(incidents: incidents, algorithmVersion: algorithmVersion, recordedAt: recordedAt)
    )
  }

  public func archived(packageID: String) -> ImportedArchive? {
    stored.first { $0.package.manifest.id == packageID }
  }

  static func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    encoder.dateEncodingStrategy = .secondsSince1970
    encoder.nonConformingFloatEncodingStrategy = .convertToString(
      positiveInfinity: "inf",
      negativeInfinity: "-inf",
      nan: "nan"
    )
    return encoder
  }

  static func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    decoder.nonConformingFloatDecodingStrategy = .convertFromString(
      positiveInfinity: "inf",
      negativeInfinity: "-inf",
      nan: "nan"
    )
    return decoder
  }

  static func checksum<T: Encodable>(for value: T) throws -> String {
    let data = try encoder().encode(value)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private func verifiedPackage(from data: Data) throws -> ImportedArchive {
    let probe: SchemaProbe
    do {
      probe = try Self.decoder().decode(SchemaProbe.self, from: data)
    } catch {
      throw ArchiveError.malformed
    }
    if probe.schemaVersion == 0 {
      return try migratedPackage(from: data)
    }
    guard probe.schemaVersion <= IncidentPackage.currentSchemaVersion else {
      throw ArchiveError.unsupportedSchemaVersion(probe.schemaVersion)
    }
    let package: IncidentPackage
    do {
      package = try Self.decoder().decode(IncidentPackage.self, from: data)
    } catch {
      throw ArchiveError.malformed
    }
    guard (try? Self.checksum(for: package.content)) == package.checksum else {
      throw ArchiveError.checksumMismatch
    }
    return ImportedArchive(package: package, migratedFrom: nil)
  }

  private func migratedPackage(from data: Data) throws -> ImportedArchive {
    let legacy: LegacyPackage
    do {
      legacy = try Self.decoder().decode(LegacyPackage.self, from: data)
    } catch {
      throw ArchiveError.malformed
    }
    guard (try? Self.checksum(for: legacy.content)) == legacy.checksum else {
      throw ArchiveError.checksumMismatch
    }
    let old = legacy.content
    let manifest = PackageManifest(
      id: old.manifest.id,
      exportedAt: old.manifest.exportedAt,
      schemaVersion: IncidentPackage.currentSchemaVersion,
      incidentStart: old.manifest.incidentStart,
      incidentEnd: old.manifest.incidentEnd,
      sampleCount: old.manifest.sampleCount
    )
    let content = PackageContent(
      schemaVersion: IncidentPackage.currentSchemaVersion,
      manifest: manifest,
      incident: old.incident,
      metricSamples: old.metricSamples,
      gaps: old.gaps,
      markers: old.markers,
      relevantProcesses: old.relevantProcesses,
      observationTransitions: [],
      summaries: old.summaries,
      ruleVersion: old.ruleVersion,
      baselineVersion: old.baselineVersion,
      processNamesRedacted: false
    )
    let package = IncidentPackage(content: content, checksum: try Self.checksum(for: content))
    return ImportedArchive(package: package, migratedFrom: 0)
  }
}

private struct SchemaProbe: Decodable {
  let content: ContentProbe

  var schemaVersion: Int {
    content.schemaVersion
  }
}

private struct ContentProbe: Decodable {
  let schemaVersion: Int
}
