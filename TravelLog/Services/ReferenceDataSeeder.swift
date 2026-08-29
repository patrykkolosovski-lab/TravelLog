import Foundation
import SwiftData

struct ReferenceDataRecord: Codable, Equatable, Sendable {
    let stableIdentifier: String
    let displayName: String
    let category: ReferenceLocationCategory
    let geometryIdentifier: String
    let continent: TravelContinent
    let flagCode: String
}

struct ReferenceDataFile: Codable, Sendable {
    let schemaVersion: Int
    let sources: [String]
    let records: [ReferenceDataRecord]
}

enum ReferenceDataError: Error, LocalizedError {
    case missingBundleResource(String)
    case unsupportedSchemaVersion(Int)
    case duplicateStableIdentifier(String)
    case duplicateCategoryGeometryIdentifier(String)

    var errorDescription: String? {
        switch self {
        case let .missingBundleResource(name):
            "The bundled reference file \(name) is missing."
        case let .unsupportedSchemaVersion(version):
            "Reference data schema version \(version) is not supported."
        case let .duplicateStableIdentifier(identifier):
            "Reference identifier \(identifier) is duplicated."
        case let .duplicateCategoryGeometryIdentifier(identifier):
            "Map geometry identifier \(identifier) is duplicated within its category."
        }
    }
}

enum ReferenceDataCatalog {
    static let resourceName = "ReferenceLocations"
    static let supportedSchemaVersion = 2

    static func load(bundle: Bundle = .main) throws -> ReferenceDataFile {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw ReferenceDataError.missingBundleResource("\(resourceName).json")
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> ReferenceDataFile {
        let file = try JSONDecoder().decode(ReferenceDataFile.self, from: data)
        guard file.schemaVersion == supportedSchemaVersion else {
            throw ReferenceDataError.unsupportedSchemaVersion(file.schemaVersion)
        }

        var stableIdentifiers = Set<String>()
        var categoryGeometryIdentifiers = Set<String>()
        for record in file.records {
            guard stableIdentifiers.insert(record.stableIdentifier).inserted else {
                throw ReferenceDataError.duplicateStableIdentifier(record.stableIdentifier)
            }
            let categoryGeometryIdentifier = "\(record.category.rawValue):\(record.geometryIdentifier)"
            guard categoryGeometryIdentifiers.insert(categoryGeometryIdentifier).inserted else {
                throw ReferenceDataError.duplicateCategoryGeometryIdentifier(
                    categoryGeometryIdentifier
                )
            }
        }
        return file
    }
}

@MainActor
enum ReferenceDataSeeder {
    static func seedIfNeeded(
        in context: ModelContext,
        bundle: Bundle = .main
    ) throws {
        try seed(ReferenceDataCatalog.load(bundle: bundle).records, in: context)
    }

    static func seed(
        _ records: [ReferenceDataRecord],
        in context: ModelContext
    ) throws {
        let existing = try context.fetch(FetchDescriptor<ReferenceLocation>())
        var existingByIdentifier = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.stableIdentifier, $0) }
        )

        for record in records {
            if let location = existingByIdentifier[record.stableIdentifier] {
                location.displayName = record.displayName
                location.category = record.category
                location.geometryIdentifier = record.geometryIdentifier
                location.continent = record.continent
                location.flagCode = record.flagCode
            } else {
                let location = ReferenceLocation(
                    stableIdentifier: record.stableIdentifier,
                    displayName: record.displayName,
                    category: record.category,
                    geometryIdentifier: record.geometryIdentifier,
                    continent: record.continent,
                    flagCode: record.flagCode
                )
                context.insert(location)
                existingByIdentifier[record.stableIdentifier] = location
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
