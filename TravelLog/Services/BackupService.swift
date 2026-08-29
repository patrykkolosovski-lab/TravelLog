import AppKit
import Foundation
import SwiftData

enum TravelLogImportMode {
    case merge
    case replace
}

struct TravelLogImportResult {
    let locationCount: Int
    let journalCount: Int
    let photoCount: Int
    let safetyBackupURL: URL?
}

struct TravelLogArchive: Codable {
    static let currentVersion = 1
    static let formatIdentifier = "com.patrykkolosovski.TravelLog.archive"

    let format: String
    let version: Int
    let exportedAt: Date
    let locations: [ArchivedLocation]
}

struct ArchivedLocation: Codable {
    let id: UUID
    let referenceIdentifier: String?
    let name: String
    let type: String
    let countryName: String?
    let isVisited: Bool
    let visitYear: Int?
    let rating: Int?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let journals: [ArchivedJournal]
    let photos: [ArchivedPhoto]
}

struct ArchivedJournal: Codable {
    let id: UUID
    let body: String
    let createdAt: Date
}

struct ArchivedPhoto: Codable {
    let id: UUID
    let originalFilename: String
    let managedFilename: String
    let createdAt: Date
    let data: Data?
}

enum BackupServiceError: LocalizedError {
    case unsupportedFormat
    case unsupportedVersion(Int)
    case duplicateIdentifier(String)
    case invalidReference(String)
    case invalidLocation(String)
    case invalidJournal
    case invalidPhoto(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            "This is not a TravelLog archive."
        case let .unsupportedVersion(version):
            "TravelLog archive version \(version) is not supported by this app version."
        case let .duplicateIdentifier(identifier):
            "The archive contains a duplicate identifier: \(identifier)."
        case let .invalidReference(identifier):
            "The archive refers to an unknown country or territory: \(identifier)."
        case let .invalidLocation(name):
            "The archive contains invalid location data for \(name)."
        case .invalidJournal:
            "The archive contains an empty or invalid journal entry."
        case let .invalidPhoto(filename):
            "The archive contains invalid photo data for \(filename)."
        }
    }
}

@MainActor
enum BackupService {
    static func makeArchive(in context: ModelContext) throws -> TravelLogArchive {
        let locations = try context.fetch(FetchDescriptor<TravelLocation>())
        return TravelLogArchive(
            format: TravelLogArchive.formatIdentifier,
            version: TravelLogArchive.currentVersion,
            exportedAt: .now,
            locations: locations.map(archiveLocation)
        )
    }

    static func encodedArchive(in context: ModelContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(makeArchive(in: context))
    }

    static func decodeAndValidate(
        _ data: Data,
        referenceIdentifiers: Set<String>
    ) throws -> TravelLogArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: TravelLogArchive
        do {
            archive = try decoder.decode(TravelLogArchive.self, from: data)
        } catch {
            throw BackupServiceError.unsupportedFormat
        }
        try validate(archive, referenceIdentifiers: referenceIdentifiers)
        return archive
    }

    static func validate(
        _ archive: TravelLogArchive,
        referenceIdentifiers: Set<String>
    ) throws {
        guard archive.format == TravelLogArchive.formatIdentifier else {
            throw BackupServiceError.unsupportedFormat
        }
        guard archive.version == TravelLogArchive.currentVersion else {
            throw BackupServiceError.unsupportedVersion(archive.version)
        }

        var locationIDs = Set<UUID>()
        var journalIDs = Set<UUID>()
        var photoIDs = Set<UUID>()
        var referenceIDs = Set<String>()
        var validatedCities: [TravelLocation] = []

        for item in archive.locations {
            guard locationIDs.insert(item.id).inserted else {
                throw BackupServiceError.duplicateIdentifier(item.id.uuidString)
            }
            guard let kind = LocationKind(rawValue: item.type) else {
                throw BackupServiceError.invalidLocation(item.name)
            }

            if kind == .city {
                guard let countryName = item.countryName,
                      let latitude = item.latitude,
                      let longitude = item.longitude else {
                    throw BackupServiceError.invalidLocation(item.name)
                }
                for city in validatedCities where TravelLocationStore.isObviousCityDuplicate(
                    city,
                    name: item.name,
                    countryName: countryName,
                    latitude: latitude,
                    longitude: longitude
                ) {
                    throw BackupServiceError.duplicateIdentifier(item.name)
                }
            } else {
                guard let referenceIdentifier = item.referenceIdentifier,
                      referenceIdentifiers.contains(referenceIdentifier) else {
                    throw BackupServiceError.invalidReference(item.referenceIdentifier ?? item.name)
                }
                guard referenceIDs.insert(referenceIdentifier).inserted else {
                    throw BackupServiceError.duplicateIdentifier(referenceIdentifier)
                }
            }

            let validated: TravelLocation
            do {
                validated = try TravelLocation.validated(
                    id: item.id,
                    referenceIdentifier: item.referenceIdentifier,
                    name: item.name,
                    kind: kind,
                    countryName: item.countryName,
                    isVisited: item.isVisited,
                    visitYear: item.visitYear,
                    rating: item.rating,
                    latitude: item.latitude,
                    longitude: item.longitude,
                    createdAt: item.createdAt
                )
            } catch {
                throw BackupServiceError.invalidLocation(item.name)
            }
            if kind == .city {
                validatedCities.append(validated)
            }

            for journal in item.journals {
                guard journalIDs.insert(journal.id).inserted,
                      !journal.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw BackupServiceError.invalidJournal
                }
            }
            for photo in item.photos {
                guard photoIDs.insert(photo.id).inserted,
                      !photo.originalFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !photo.managedFilename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw BackupServiceError.invalidPhoto(photo.originalFilename)
                }
                if let data = photo.data, NSImage(data: data) == nil {
                    throw BackupServiceError.invalidPhoto(photo.originalFilename)
                }
            }
        }
    }

    static func importArchive(
        _ archive: TravelLogArchive,
        mode: TravelLogImportMode,
        referenceIdentifiers: Set<String>,
        in context: ModelContext,
        photoDirectory customPhotoDirectory: URL? = nil,
        backupDirectory customBackupDirectory: URL? = nil
    ) throws -> TravelLogImportResult {
        try validate(archive, referenceIdentifiers: referenceIdentifiers)

        let safetyBackupURL = mode == .replace
            ? try createSafetyBackup(in: context, directory: customBackupDirectory)
            : nil
        let photoDirectory = try customPhotoDirectory ?? AppDirectories.photos
        try FileManager.default.createDirectory(
            at: photoDirectory,
            withIntermediateDirectories: true
        )
        let existingLocations = try context.fetch(FetchDescriptor<TravelLocation>())
        let oldManagedFilenames = mode == .replace
            ? existingLocations.flatMap { $0.photos.map(\.managedFilename) }
            : []
        let existingJournals = try context.fetch(FetchDescriptor<JournalEntry>())
        let existingPhotos = try context.fetch(FetchDescriptor<TravelPhoto>())
        let existingJournalIDs = Set(existingJournals.map(\.id))
        let existingPhotoIDs = Set(existingPhotos.map(\.id))

        var stagedFiles: [UUID: (managedFilename: String, url: URL)] = [:]
        var installedURLs: [URL] = []

        do {
            for location in archive.locations {
                for photo in location.photos {
                    if mode == .merge && existingPhotoIDs.contains(photo.id) {
                        continue
                    }
                    guard let data = photo.data else { continue }
                    let filename = uniqueImportedFilename(for: photo, in: photoDirectory)
                    let stagedURL = FileManager.default.temporaryDirectory
                        .appending(path: "TravelLog-Import-\(UUID().uuidString)")
                    try data.write(to: stagedURL, options: .atomic)
                    stagedFiles[photo.id] = (filename, stagedURL)
                }
            }

            for staged in stagedFiles.values {
                let destination = photoDirectory.appending(path: staged.managedFilename)
                try FileManager.default.moveItem(at: staged.url, to: destination)
                installedURLs.append(destination)
            }

            try context.transaction {
                if mode == .replace {
                    for location in existingLocations {
                        context.delete(location)
                    }
                }
                try apply(
                    archive,
                    mode: mode,
                    existingLocations: mode == .replace ? [] : existingLocations,
                    existingJournalIDs: mode == .replace ? [] : existingJournalIDs,
                    existingPhotoIDs: mode == .replace ? [] : existingPhotoIDs,
                    stagedFiles: stagedFiles,
                    context: context
                )
            }
        } catch {
            context.rollback()
            for staged in stagedFiles.values {
                try? FileManager.default.removeItem(at: staged.url)
            }
            for url in installedURLs {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }

        if mode == .replace {
            for filename in oldManagedFilenames {
                try? FileManager.default.removeItem(at: photoDirectory.appending(path: filename))
            }
        }

        return TravelLogImportResult(
            locationCount: archive.locations.count,
            journalCount: archive.locations.reduce(0) { $0 + $1.journals.count },
            photoCount: archive.locations.reduce(0) { $0 + $1.photos.count },
            safetyBackupURL: safetyBackupURL
        )
    }

    private static func apply(
        _ archive: TravelLogArchive,
        mode: TravelLogImportMode,
        existingLocations: [TravelLocation],
        existingJournalIDs: Set<UUID>,
        existingPhotoIDs: Set<UUID>,
        stagedFiles: [UUID: (managedFilename: String, url: URL)],
        context: ModelContext
    ) throws {
        var locationsByID = Dictionary(
            uniqueKeysWithValues: existingLocations.map { ($0.id, $0) }
        )
        var locationsByReference = Dictionary(
            existingLocations.compactMap { location in
                location.referenceIdentifier.map { ($0, location) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        for item in archive.locations {
            guard let kind = LocationKind(rawValue: item.type) else {
                throw BackupServiceError.invalidLocation(item.name)
            }

            let target: TravelLocation
            if let existing = locationsByID[item.id] {
                target = existing
            } else if let referenceIdentifier = item.referenceIdentifier,
                      let existing = locationsByReference[referenceIdentifier] {
                target = existing
            } else if kind == .city,
                      let existing = existingLocations.first(where: { location in
                          guard let countryName = item.countryName,
                                let latitude = item.latitude,
                                let longitude = item.longitude else { return false }
                          return TravelLocationStore.isObviousCityDuplicate(
                              location,
                              name: item.name,
                              countryName: countryName,
                              latitude: latitude,
                              longitude: longitude
                          )
                      }) {
                target = existing
            } else {
                target = TravelLocation(
                    id: item.id,
                    referenceIdentifier: item.referenceIdentifier,
                    name: item.name,
                    kind: kind,
                    createdAt: item.createdAt
                )
                context.insert(target)
                locationsByID[target.id] = target
                if let referenceIdentifier = item.referenceIdentifier {
                    locationsByReference[referenceIdentifier] = target
                }
            }

            try target.update(
                referenceIdentifier: item.referenceIdentifier,
                name: item.name,
                kind: kind,
                countryName: item.countryName,
                isVisited: item.isVisited,
                visitYear: item.visitYear,
                rating: item.rating,
                latitude: item.latitude,
                longitude: item.longitude
            )

            for journal in item.journals where !existingJournalIDs.contains(journal.id) {
                let entry = JournalEntry(
                    id: journal.id,
                    body: journal.body,
                    createdAt: journal.createdAt,
                    location: target
                )
                target.journalEntries.append(entry)
                context.insert(entry)
            }

            for photo in item.photos where !existingPhotoIDs.contains(photo.id) {
                let managedFilename = stagedFiles[photo.id]?.managedFilename
                    ?? "missing-\(photo.id.uuidString.lowercased())"
                let imported = TravelPhoto(
                    id: photo.id,
                    originalFilename: photo.originalFilename,
                    managedFilename: managedFilename,
                    createdAt: photo.createdAt,
                    location: target
                )
                target.photos.append(imported)
                context.insert(imported)
            }
        }
    }

    private static func archiveLocation(_ location: TravelLocation) -> ArchivedLocation {
        ArchivedLocation(
            id: location.id,
            referenceIdentifier: location.referenceIdentifier,
            name: location.name,
            type: location.kind.rawValue,
            countryName: location.countryName,
            isVisited: location.isVisited,
            visitYear: location.visitYear,
            rating: location.rating,
            latitude: location.latitude,
            longitude: location.longitude,
            createdAt: location.createdAt,
            journals: location.journalEntries.map {
                ArchivedJournal(id: $0.id, body: $0.body, createdAt: $0.createdAt)
            },
            photos: location.photos.map { photo in
                let data = ManagedPhotoStore.fileURL(for: photo).flatMap { try? Data(contentsOf: $0) }
                return ArchivedPhoto(
                    id: photo.id,
                    originalFilename: photo.originalFilename,
                    managedFilename: photo.managedFilename,
                    createdAt: photo.createdAt,
                    data: data
                )
            }
        )
    }

    private static func createSafetyBackup(
        in context: ModelContext,
        directory customDirectory: URL?
    ) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let filename = "TravelLog-Safety-\(formatter.string(from: .now)).travellog"
        let directory = try customDirectory ?? AppDirectories.backups
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appending(path: filename)
        try encodedArchive(in: context).write(to: url, options: .atomic)
        return url
    }

    private static func uniqueImportedFilename(
        for photo: ArchivedPhoto,
        in directory: URL
    ) -> String {
        let sourceExtension = URL(fileURLWithPath: photo.managedFilename).pathExtension
        let fallbackExtension = URL(fileURLWithPath: photo.originalFilename).pathExtension
        let fileExtension = sourceExtension.isEmpty ? fallbackExtension : sourceExtension
        let suffix = fileExtension.isEmpty ? "" : ".\(fileExtension.lowercased())"

        while true {
            let candidate = "\(UUID().uuidString.lowercased())\(suffix)"
            if !FileManager.default.fileExists(
                atPath: directory.appending(path: candidate).path
            ) {
                return candidate
            }
        }
    }
}
