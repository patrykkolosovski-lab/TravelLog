import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import TravelLog

final class WorldMapDataTests: XCTestCase {
    func testEveryReferenceLocationHasBundledMapGeometry() async throws {
        let records = try ReferenceDataCatalog.load().records
        let mapData = try await GeoJSONMapService.load()
        let geometryIdentifiers = Set(
            mapData.shapes.map(\.geometryIdentifier)
                + mapData.markers.map(\.geometryIdentifier)
        )

        let missingIdentifiers = records
            .map(\.geometryIdentifier)
            .filter { !geometryIdentifiers.contains($0) }

        XCTAssertEqual(missingIdentifiers, [])
    }

    @MainActor
    func testWorldMapRendersAtSeveralWindowSizes() async throws {
        let schema = Schema([
            TravelLocation.self,
            JournalEntry.self,
            TravelPhoto.self,
            ReferenceLocation.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        try ReferenceDataSeeder.seed(ReferenceDataCatalog.load().records, in: container.mainContext)
        let france = try TravelLocation.validated(
            referenceIdentifier: "un:FRA",
            name: "France",
            kind: .country,
            isVisited: true,
            visitYear: 2022,
            rating: 9,
            currentYear: 2026
        )
        let paris = try TravelLocation.validated(
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
        container.mainContext.insert(france)
        container.mainContext.insert(paris)
        try container.mainContext.save()

        let sizes = [
            CGSize(width: 840, height: 580),
            CGSize(width: 1180, height: 760),
            CGSize(width: 1500, height: 800)
        ]

        for size in sizes {
            let rootView = ContentView().modelContainer(container)
            let hostingView = NSHostingView(rootView: rootView)
            hostingView.frame = CGRect(origin: .zero, size: size)
            let window = NSWindow(
                contentRect: hostingView.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.orderFrontRegardless()

            try await Task.sleep(for: .milliseconds(600))
            hostingView.layoutSubtreeIfNeeded()

            guard let representation = hostingView.bitmapImageRepForCachingDisplay(
                in: hostingView.bounds
            ) else {
                XCTFail("Unable to create a map snapshot at \(size)")
                window.orderOut(nil)
                continue
            }
            hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
            guard let imageData = representation.representation(using: .png, properties: [:]) else {
                XCTFail("Unable to encode a map snapshot at \(size)")
                window.orderOut(nil)
                continue
            }

            let snapshotURL = FileManager.default.temporaryDirectory
                .appending(path: "TravelLog-\(Int(size.width))x\(Int(size.height)).png")
            try imageData.write(to: snapshotURL, options: .atomic)
            XCTAssertGreaterThan(imageData.count, 50_000)
            window.orderOut(nil)
        }
    }

    @MainActor
    func testEditorsAndInspectorRender() async throws {
        let schema = Schema([
            TravelLocation.self,
            JournalEntry.self,
            TravelPhoto.self,
            ReferenceLocation.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        try ReferenceDataSeeder.seed(ReferenceDataCatalog.load().records, in: context)

        let france = try TravelLocation.validated(
            referenceIdentifier: "un:FRA",
            name: "France",
            kind: .country,
            isVisited: true,
            visitYear: 2022,
            rating: 9,
            currentYear: 2026
        )
        let journal = JournalEntry(
            body: "A long evening walk along the Seine.",
            location: france
        )
        let photo = TravelPhoto(
            originalFilename: "paris-evening.jpg",
            managedFilename: "missing-preview.jpg",
            location: france
        )
        let paris = try TravelLocation.validated(
            name: "Paris",
            kind: .city,
            countryName: "France",
            isVisited: true,
            visitYear: 2023,
            rating: 10,
            latitude: 48.8566,
            longitude: 2.3522,
            currentYear: 2026
        )
        let parisJournal = JournalEntry(
            body: "The city felt entirely different in the early morning.",
            location: paris
        )
        let parisPhoto = TravelPhoto(
            originalFilename: "paris-morning.jpg",
            managedFilename: "missing-city-preview.jpg",
            location: paris
        )
        france.journalEntries.append(journal)
        france.photos.append(photo)
        paris.journalEntries.append(parisJournal)
        paris.photos.append(parisPhoto)
        context.insert(france)
        context.insert(paris)
        try context.save()

        let references = try context.fetch(FetchDescriptor<ReferenceLocation>())
        let locations = try context.fetch(FetchDescriptor<TravelLocation>())

        try await snapshot(
            ReferenceLocationEditorSheet(
                referenceLocations: references,
                travelLocations: locations,
                initialReferenceIdentifier: "un:FRA",
                didSave: { _ in }
            )
            .modelContainer(container),
            size: CGSize(width: 760, height: 540),
            name: "TravelLog-ReferenceEditor"
        )

        let cityRequest = CityEditorRequest(
            result: CitySearchResult(
                name: "Paris",
                countryName: "France",
                regionName: "Ile-de-France",
                latitude: 48.8566,
                longitude: 2.3522
            )
        )
        try await snapshot(
            CityLocationEditorSheet(request: cityRequest, didSave: { _ in })
                .modelContainer(container),
            size: CGSize(width: 500, height: 430),
            name: "TravelLog-CityEditor"
        )

        try await snapshot(
            LocationDetailInspector(
                selection: .reference("un:FRA"),
                referenceLocations: references,
                travelLocations: locations,
                edit: {},
                delete: { _ in },
                editJournal: { _ in },
                deleteJournal: { _ in },
                removePhoto: { _ in },
                close: {}
            ),
            size: CGSize(width: 340, height: 700),
            name: "TravelLog-Inspector"
        )

        try await snapshot(
            PhotoImportSheet(locations: locations, didSave: { _ in })
                .modelContainer(container),
            size: CGSize(width: 760, height: 500),
            name: "TravelLog-PhotoImport"
        )

        try await snapshot(
            JournalEditorSheet(
                locations: locations,
                request: JournalEditorRequest(initialLocationID: france.id),
                didSave: { _ in }
            )
            .modelContainer(container),
            size: CGSize(width: 820, height: 540),
            name: "TravelLog-JournalEditor"
        )

        try await snapshot(
            StatsSheet(locations: locations, referenceLocations: references),
            size: CGSize(width: 720, height: 720),
            name: "TravelLog-Stats"
        )

        try await snapshot(
            BackupSettingsView().modelContainer(container),
            size: CGSize(width: 520, height: 280),
            name: "TravelLog-BackupSettings"
        )

        try await snapshot(
            PhotoPreviewSheet(photo: photo, remove: {}),
            size: CGSize(width: 640, height: 480),
            name: "TravelLog-MissingPhoto"
        )
    }

    @MainActor
    private func snapshot<V: View>(
        _ view: V,
        size: CGSize,
        name: String
    ) async throws {
        let hostingView = NSHostingView(
            rootView: view.background(Color(nsColor: .windowBackgroundColor))
        )
        hostingView.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.orderFrontRegardless()

        try await Task.sleep(for: .milliseconds(400))
        hostingView.layoutSubtreeIfNeeded()

        guard let representation = hostingView.bitmapImageRepForCachingDisplay(
            in: hostingView.bounds
        ) else {
            window.orderOut(nil)
            XCTFail("Unable to create \(name) snapshot")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        guard let imageData = representation.representation(using: .png, properties: [:]) else {
            window.orderOut(nil)
            XCTFail("Unable to encode \(name) snapshot")
            return
        }

        try imageData.write(
            to: FileManager.default.temporaryDirectory.appending(path: "\(name).png"),
            options: .atomic
        )
        XCTAssertGreaterThan(imageData.count, 10_000)
        window.orderOut(nil)
    }
}
