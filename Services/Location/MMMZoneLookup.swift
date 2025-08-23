import Foundation
import MapKit
import CoreLocation

// MARK: - ZonePoly and Helpers

struct ZonePoly {
    let bbox: MKMapRect
    let ring: [CLLocationCoordinate2D]
    let mm: Int
}

extension MKPolygon {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: self.pointCount)
        self.getCoordinates(&coords, range: NSRange(location: 0, length: self.pointCount))
        return coords
    }
}

// MARK: - MMMZoneLookup

final class MMMZoneLookup {
    static let shared = MMMZoneLookup()
    private let polygons: [ZonePoly]
    
    private init() {
        // Load polygons
        let url = Bundle.main.url(forResource: "mmm_sa1", withExtension: "geojson")!
        print("[MMMZoneLookup] Loading polygons from: \(url)")
        let features = try! MKGeoJSONDecoder().decode(Data(contentsOf: url))
            .compactMap { $0 as? MKGeoJSONFeature }
        
        var polys: [ZonePoly] = []
        for f in features {
            for geometry in f.geometry {
                if let poly = geometry as? MKPolygon {
                    let props = String(data: f.properties ?? Data(), encoding: .utf8) ?? ""
                    let mm = MMMZoneLookup.extractMMMCode(from: props)
                    polys.append(ZonePoly(bbox: poly.boundingMapRect, ring: poly.coordinates, mm: mm))
                } else if let multiPoly = geometry as? MKMultiPolygon {
                    let props = String(data: f.properties ?? Data(), encoding: .utf8) ?? ""
                    let mm = MMMZoneLookup.extractMMMCode(from: props)
                    for poly in multiPoly.polygons {
                        polys.append(ZonePoly(bbox: poly.boundingMapRect, ring: poly.coordinates, mm: mm))
                    }
                }
            }
        }
        print("[MMMZoneLookup] Loaded \(polys.count) polygons for MMM zones.")
        self.polygons = polys
    }
    
    // MARK: - MMM Lookup
    
    /// Looks up the MMM zone for a given coordinate.
    /// This is the primary method - all MMM zone lookups should use coordinates.
    func mmm(for coord: CLLocationCoordinate2D) -> Int? {
        print("[MMMZoneLookup] Looking up MMM zone for coordinate: \(coord.latitude), \(coord.longitude)")
        let mapPoint = MKMapPoint(coord)
        let candidates = polygons.filter { $0.bbox.contains(mapPoint) }
        print("[MMMZoneLookup] Found \(candidates.count) candidate polygons containing the point's bounding box.")
        for candidate in candidates {
            if Self.contains(coord, in: candidate.ring) {
                print("[MMMZoneLookup] Point is inside polygon with MMM code: \(candidate.mm)")
                return candidate.mm
            }
        }
        print("[MMMZoneLookup] No polygon contains the point.")
        return nil
    }
    
    // MARK: - Helpers
    
    static func contains(_ c: CLLocationCoordinate2D, in ring: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude
            if ((yi > c.latitude) != (yj > c.latitude)) &&
                (c.longitude < (xj - xi) * (c.latitude - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        if inside {
            print("[MMMZoneLookup] Point-in-polygon: INSIDE")
        } else {
            print("[MMMZoneLookup] Point-in-polygon: OUTSIDE")
        }
        return inside
    }
    
    static func extractMMMCode(from props: String) -> Int {
        if let range = props.range(of: "\"MMM_CODE23\":") {
            let after = props[range.upperBound...]
            let codeStr = after.prefix { $0.isNumber }
            let code = Int(codeStr) ?? 0
            print("[MMMZoneLookup] Extracted MMM code: \(code)")
            return code
        }
        print("[MMMZoneLookup] No MMM code found in properties string.")
        return 0
    }
    
}
