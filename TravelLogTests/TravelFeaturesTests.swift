import AppKit
import SwiftData
import XCTest
@testable import TravelLog

@MainActor
final class TravelFeaturesTests: XCTestCase {
    func testJournalCreateEditAndDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let location = TravelLocation(name: "Paris", kind: .city)
        try location.update(
            referenceIdentifier: nil,
            name: "Paris",
            kind: .city,
            countryName: "France",
            isVisited: true,
            visitYear: 2022,
            rating: 9,
            latitude: 48.8566,
            longitude: 2.3522,
            currentYear: 2026
        )
        context.insert(location)
        try context.save()

        let entry = try JournalStore.save(
            body: "  First thoughts.  ",
            for: location,
            in: context
        )
        XCTAssertEqual(entry.body, "First thoughts.")
        XCTAssertNotNil(entry.location)

        _ = try JournalStore.save(
            body: "Updated thoughts.",
            for: location,
            existing: entry,
            in: context
        )
        XCTAssertEqual(entry.body, "Updated thoughts.")

        try JournalStore.delete(entry, from: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalEntry>()), 0)
    }

    func testManagedPhotoImportUsesUniqueFilesAndRemovalDeletesFile() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let location = TravelLocation(name: "France", kind: .country)
        context.insert(location)
        try context.save()
        let directory = temporaryDirectory(named: "photos")
        let imageData = try makePNGData()

        let photos = try ManagedPhotoStore.importPhotos(
            [
                PhotoImportPayload(originalFilename: "trip.png", data: imageData),
                PhotoImportPayload(originalFilename: "trip.png", data: imageData)
            ],
            for: location,
            in: context,
            photoDirectory: directory
        )

        XCTAssertEqual(photos.count, 2)
        XCTAssertNotEqual(photos[0].managedFilename, photos[1].managedFilename)
        let firstURL = directory.appending(path: photos[0].managedFilename)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstURL.path))

        try ManagedPhotoStore.remove(
            photos[0],
            from: context,
            photoDirectory: directory
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: firstURL.path))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TravelPhoto>()), 1)
    }

    func testStatisticsKeepCountriesAndTerritoriesSeparate() throws {
        let country = try TravelLocation.validated(
            referenceIdentifier: "un:FRA",
            name: "France",
            kind: .country,
            isVisited: true,
            visitYear: 2022,
            rating: 8,
            currentYear: 2026
        )
        let territory = try TravelLocation.validated(
            referenceIdentifier: "nsgt:GIB",
            name: "Gibraltar",
            kind: .territory,
            isVisited: true,
            visitYear: 2022,
            rating: 10,
            currentYear: 2026
        )
        let city = try TravelLocation.validated(
            name: "Paris",
            kind: .city,
            countryName: "France",
            isVisited: true,
            visitYear: 2023,
            rating: 9,
            latitude: 48.8566,
            longitude: 2.3522,
            currentYear: 2026
        )

        let franceReference = ReferenceLocation(
            stableIdentifier: "un:FRA",
            displayName: "France",
            category: .country,
            geometryIdentifier: "FRA",
            continent: .europe,
            flagCode: "FR"
        )
        let gibraltarReference = ReferenceLocation(
            stableIdentifier: "nsgt:GIB",
            displayName: "Gibraltar",
            category: .territory,
            geometryIdentifier: "GIB",
            continent: .europe,
            flagCode: "GI"
        )

        let stats = TravelStatisticsService.calculate(
            from: [country, territory, city],
            references: [franceReference, gibraltarReference]
        )
        XCTAssertEqual(stats.visitedCountryCount, 1)
        XCTAssertEqual(stats.visitedTerritoryCount, 1)
        XCTAssertEqual(stats.cityCount, 1)
        XCTAssertEqual(stats.continentCount, 1)
        XCTAssertEqual(stats.locationsByYear.map(\.year), [2023, 2022])
        XCTAssertEqual(stats.locationsByYear.map(\.count), [1, 2])
        XCTAssertEqual(stats.combinedCoverage, 2.0 / 210.0, accuracy: 0.000_001)
        XCTAssertEqual(stats.visitedCountries.first?.flag, "🇫🇷")
        XCTAssertEqual(
            stats.averageRating(
                continent: .europe,
                includedKinds: [.country, .territory]
            ),
            9
        )
        XCTAssertEqual(
            stats.filteredRatings(continent: nil, includedKinds: [.city]).map(\.name),
            ["Paris"]
        )
        let europeCoverage = try XCTUnwrap(
            stats.continentCoverage.first { $0.continent == .europe }
        )
        XCTAssertEqual(europeCoverage.visited, 2)
        XCTAssertEqual(europeCoverage.total, 2)
    }

    func testStatisticsResolveCityCountryUsingFlagMetadata() throws {
        let unitedStates = ReferenceLocation(
            stableIdentifier: "un:USA",
            displayName: "United States of America",
            category: .country,
            geometryIdentifier: "USA",
            continent: .northAmerica,
            flagCode: "US"
        )
        let newYork = try TravelLocation.validated(
            name: "New York",
            kind: .city,
            countryName: "United States",
            isVisited: true,
            visitYear: 2024,
            rating: 9,
            latitude: 40.7128,
            longitude: -74.006,
            currentYear: 2026
        )

        let stats = TravelStatisticsService.calculate(
            from: [newYork],
            references: [unitedStates]
        )

        XCTAssertEqual(stats.loggedCities.first?.continent, .northAmerica)
        XCTAssertEqual(stats.loggedCities.first?.flagCode, "US")
        XCTAssertEqual(stats.continentCount, 1)
    }

    func testArchiveRoundTripMergePreservesJournal() throws {
        let source = try makeContainer()
        let sourceContext = source.mainContext
        let france = try TravelLocation.validated(
            referenceIdentifier: "un:FRA",
            name: "France",
            kind: .country,
            isVisited: true,
            visitYear: 2022,
            rating: 9,
            currentYear: 2026
        )
        let entry = JournalEntry(body: "Archive journal.", location: france)
        france.journalEntries.append(entry)
        sourceContext.insert(france)
        try sourceContext.save()

        let data = try BackupService.encodedArchive(in: sourceContext)
        let references: Set<String> = ["un:FRA"]
        let archive = try BackupService.decodeAndValidate(
            data,
            referenceIdentifiers: references
        )

        let destination = try makeContainer()
        let result = try BackupService.importArchive(
            archive,
            mode: .merge,
            referenceIdentifiers: references,
            in: destination.mainContext,
            photoDirectory: temporaryDirectory(named: "merge-photos"),
            backupDirectory: temporaryDirectory(named: "merge-backups")
        )

        XCTAssertEqual(result.locationCount, 1)
        XCTAssertEqual(result.journalCount, 1)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<TravelLocation>()), 1)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<JournalEntry>()), 1)
    }

    func testReplacementCreatesSafetyBackup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let france = try TravelLocation.validated(
            referenceIdentifier: "un:FRA",
            name: "France",
            kind: .country,
            isVisited: true,
            visitYear: 2022,
            currentYear: 2026
        )
        context.insert(france)
        try context.save()

        let germany = ArchivedLocation(
            id: UUID(),
            referenceIdentifier: "un:DEU",
            name: "Germany",
            type: LocationKind.country.rawValue,
            countryName: nil,
            isVisited: true,
            visitYear: 2024,
            rating: 8,
            latitude: nil,
            longitude: nil,
            createdAt: .now,
            journals: [],
            photos: []
        )
        let archive = TravelLogArchive(
            format: TravelLogArchive.formatIdentifier,
            version: TravelLogArchive.currentVersion,
            exportedAt: .now,
            locations: [germany]
        )
        let backupDirectory = temporaryDirectory(named: "replacement-backups")
        let result = try BackupService.importArchive(
            archive,
            mode: .replace,
            referenceIdentifiers: ["un:FRA", "un:DEU"],
            in: context,
            photoDirectory: temporaryDirectory(named: "replacement-photos"),
            backupDirectory: backupDirectory
        )

        let saved = try context.fetch(FetchDescriptor<TravelLocation>())
        XCTAssertEqual(saved.map(\.name), ["Germany"])
        XCTAssertNotNil(result.safetyBackupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.safetyBackupURL!.path))
    }

    func testInvalidArchiveDoesNotModifyDatabase() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(TravelLocation(name: "Existing", kind: .country))
        try context.save()

        let invalid = TravelLogArchive(
            format: TravelLogArchive.formatIdentifier,
            version: TravelLogArchive.currentVersion,
            exportedAt: .now,
            locations: [
                ArchivedLocation(
                    id: UUID(),
                    referenceIdentifier: "un:FRA",
                    name: "France",
                    type: LocationKind.country.rawValue,
                    countryName: nil,
                    isVisited: true,
                    visitYear: 2022,
                    rating: nil,
                    latitude: nil,
                    longitude: nil,
                    createdAt: .now,
                    journals: [ArchivedJournal(id: UUID(), body: "   ", createdAt: .now)],
                    photos: []
                )
            ]
        )

        XCTAssertThrowsError(
            try BackupService.importArchive(
                invalid,
                mode: .merge,
                referenceIdentifiers: ["un:FRA"],
                in: context,
                photoDirectory: temporaryDirectory(named: "invalid-photos"),
                backupDirectory: temporaryDirectory(named: "invalid-backups")
            )
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TravelLocation>()), 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            TravelLocation.self,
            JournalEntry.self,
            TravelPhoto.self,
            ReferenceLocation.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func temporaryDirectory(named name: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "TravelLogTests-\(name)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makePNGData() throws -> Data {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.systemRed.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let representation = NSBitmapImageRep(data: tiff),
              let data = representation.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
