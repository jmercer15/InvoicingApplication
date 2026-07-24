import CoreLocation
import XCTest
@testable import Core

final class MMMZoneLookupTests: XCTestCase {
    private func productionGeoJSONURL(file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("InvoicingApplication")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Data")
            .appendingPathComponent("mmm_sa1.geojson")
    }

    private func makeLookup() throws -> MMMZoneLookup {
        let url = productionGeoJSONURL()
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: url.path),
            "Expected MMM GeoJSON test input at \(url.path)"
        )
        return try MMMZoneLookup(resourceURL: url)
    }

    func testLookupReturnsExpectedCodesForKnownCoordinates() throws {
        let lookup = try makeLookup()

        XCTAssertEqual(
            lookup.mmm(for: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
            1,
            "Sydney CBD should classify as MMM 1."
        )
        XCTAssertEqual(
            lookup.mmm(for: CLLocationCoordinate2D(latitude: -42.8821, longitude: 147.3272)),
            2,
            "Hobart CBD should classify as MMM 2."
        )
        XCTAssertEqual(
            lookup.mmm(for: CLLocationCoordinate2D(latitude: -23.6980, longitude: 133.8807)),
            6,
            "Alice Springs should classify as MMM 6."
        )
    }

    func testLookupReturnsNilOutsideAllMMMBoundaries() throws {
        let lookup = try makeLookup()

        XCTAssertNil(
            lookup.mmm(for: CLLocationCoordinate2D(latitude: 0, longitude: 0)),
            "A coordinate far outside Australia should not match any MMM polygon."
        )
    }
}
