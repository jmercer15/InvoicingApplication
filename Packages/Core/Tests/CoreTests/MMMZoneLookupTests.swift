import CoreLocation
import Foundation
import Testing
@testable import Core

@Suite struct MMMZoneLookupTests {
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
        #expect(FileManager.default.fileExists(atPath: url.path), "Expected MMM GeoJSON test input at \(url.path)")
        return try MMMZoneLookup(resourceURL: url)
    }

    @Test func LookupReturnsExpectedCodesForKnownCoordinates() throws {
        let lookup = try makeLookup()

        #expect(lookup.mmm(for: CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)) == 1, "Sydney CBD should classify as MMM 1.")
        #expect(lookup.mmm(for: CLLocationCoordinate2D(latitude: -42.8821, longitude: 147.3272)) == 2, "Hobart CBD should classify as MMM 2.")
        #expect(lookup.mmm(for: CLLocationCoordinate2D(latitude: -23.6980, longitude: 133.8807)) == 6, "Alice Springs should classify as MMM 6.")
    }

    @Test func LookupReturnsNilOutsideAllMMMBoundaries() throws {
        let lookup = try makeLookup()

        #expect(lookup.mmm(for: CLLocationCoordinate2D(latitude: 0, longitude: 0)) == nil, "A coordinate far outside Australia should not match any MMM polygon.")
    }
}
