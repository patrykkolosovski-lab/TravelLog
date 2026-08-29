import SwiftData
import XCTest
@testable import TravelLog

@MainActor
final class TravelDataModelTests: XCTestCase {
    func testUnvisitedLocationClearsVisitYear() throws {
        let location = TravelLocation(name: "France", kind: .country)

        try location.update(
            referenceIdentifier: "un:FRA",
            name: "France",
            kind: .country,
            countryName: nil,
            isVisited: false,
            visitYear: 2022,
            rating: 8,
            latitude: nil,
            longitude: nil,
            currentYear: 2026
        )

        XCTAssertNil(location.visitYear)
    }

    func testRatingOutsideZeroToTenIsRejected() {
        XCTAssertThrowsError(
            try TravelLocation.validated(
                name: "France",
                kind: .country,
                isVisited: true,
                visitYear: 2022,
                rating: 11,
                currentYear: 2026
            )
        ) { error in
            XCTAssertEqual(error as? TravelDataValidationError, .invalidRating(11))
        }
    }

    func testFutureVisitYearIsRejected() {
        XCTAssertThrowsError(
            try TravelLocation.validated(
                name: "France",
                kind: .country,
                isVisited: true,
                visitYear: 2027,
                currentYear: 2026
            )
        ) { error in
            XCTAssertEqual(error as? TravelDataValidationError, .invalidVisitYear(2027))
        }
    }

    func testVisitedLocationRequiresYear() {
        XCTAssertThrowsError(
            try TravelLocation.validated(
                name: "France",
                kind: .country,
                isVisited: true,
                visitYear: nil
            )
        ) { error in
            XCTAssertEqual(error as? TravelDataValidationError, .missingVisitYear)
        }
    }

    func testCityRequiresCountry() {
        XCTAssertThrowsError(
            try TravelLocation.validated(
                name: "Paris",
                kind: .city,
                countryName: nil,
                latitude: 48.8566,
                longitude: 2.3522
            )
        ) { error in
            XCTAssertEqual(error as? TravelDataValidationError, .cityRequiresCountry)
        }
    }

    func testDeletingLocationCascadesToJournalEntriesAndPhotos() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let location = TravelLocation(name: "France", kind: .country)
        let entry = JournalEntry(body: "A memorable visit.", location: location)
        let photo = TravelPhoto(
            originalFilename: "paris.jpg",
            managedFilename: "photo-id.jpg",
            location: location
        )
        location.journalEntries.append(entry)
        location.photos.append(photo)
        context.insert(location)
        try context.save()

        context.delete(location)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TravelLocation>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TravelPhoto>()), 0)
    }

    func testSavingReferenceLocationUpdatesExistingRecord() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reference = ReferenceLocation(
            stableIdentifier: "un:FRA",
            displayName: "France",
            category: .country,
            geometryIdentifier: "FRA"
        )
        context.insert(reference)

        let first = try TravelLocationStore.saveReferenceLocation(
            reference,
            isVisited: true,
            visitYear: 2021,
            rating: 8,
            in: context
        )
        let second = try TravelLocationStore.saveReferenceLocation(
            reference,
            isVisited: true,
            visitYear: 2023,
            rating: 9,
            in: context
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.visitYear, 2023)
        XCTAssertEqual(second.rating, 9)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TravelLocation>()), 1)
    }

    func testObviousCityDuplicateIsRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext

        _ = try TravelLocationStore.saveCity(
            name: "Paris",
            countryName: "France",
            isVisited: true,
            visitYear: 2022,
            rating: 9,
            latitude: 48.8566,
            longitude: 2.3522,
            in: context
        )

        XCTAssertThrowsError(
            try TravelLocationStore.saveCity(
                name: "  Páris ",
                countryName: "FRANCE",
                isVisited: true,
                visitYear: 2024,
                rating: 8,
                latitude: 48.857,
                longitude: 2.353,
                in: context
            )
        ) { error in
            XCTAssertEqual(error as? TravelLocationStoreError, .duplicateCity)
        }
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
}
