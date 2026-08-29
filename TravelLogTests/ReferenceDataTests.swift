import SwiftData
import XCTest
@testable import TravelLog

@MainActor
final class ReferenceDataTests: XCTestCase {
    func testCatalogHasExpectedCountsAndUniqueIdentifiers() throws {
        let records = try ReferenceDataCatalog.load().records
        let countries = records.filter { $0.category == .country }
        let territories = records.filter { $0.category == .territory }

        XCTAssertEqual(countries.count, 193)
        XCTAssertEqual(territories.count, 17)
        XCTAssertEqual(Set(records.map(\.stableIdentifier)).count, records.count)
        XCTAssertEqual(Set(records.map(\.geometryIdentifier)).count, records.count)
        XCTAssertEqual(Set(records.map(\.continent)), Set(TravelContinent.allCases))
        XCTAssertTrue(records.allSatisfy { $0.flagCode.count == 2 })
        XCTAssertEqual(
            Set(records.map { "\($0.category.rawValue):\($0.geometryIdentifier)" }).count,
            records.count
        )
    }

    func testSeederIsIdempotent() throws {
        let records = try ReferenceDataCatalog.load().records
        let schema = Schema([ReferenceLocation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        try ReferenceDataSeeder.seed(records, in: context)
        try ReferenceDataSeeder.seed(records, in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReferenceLocation>()), 210)
        let seeded = try context.fetch(FetchDescriptor<ReferenceLocation>())
        let france = try XCTUnwrap(seeded.first { $0.stableIdentifier == "un:FRA" })
        XCTAssertEqual(france.continent, .europe)
        XCTAssertEqual(france.flagCode, "FR")
    }
}
