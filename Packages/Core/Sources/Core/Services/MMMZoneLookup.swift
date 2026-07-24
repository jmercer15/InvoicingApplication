import CoreLocation
import Foundation
import MapKit
import os

// MARK: - ZonePoly and Helpers

struct ZonePoly {
    let bbox: MKMapRect
    let ring: [CLLocationCoordinate2D]
    let mm: Int
}

extension MKPolygon {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

// MARK: - Spatial index (grid buckets by lat/lon)

private struct MMMZoneSpatialIndex: Sendable {
    let cellSizeDegrees: Double
    /// Spatial hash → polygon indices in the parallel `polygons` array passed at lookup time.
    private let buckets: [Int: [Int]]

    init(polygons: [ZonePoly], cellSizeDegrees: Double = 0.25) {
        self.cellSizeDegrees = cellSizeDegrees
        var buckets: [Int: [Int]] = [:]
        buckets.reserveCapacity(polygons.count / 8)
        for (idx, poly) in polygons.enumerated() {
            guard let bbox = Self.latLonBounds(ring: poly.ring) else { continue }
            for key in Self.overlappingCellKeys(bounding: bbox, cellSize: cellSizeDegrees) {
                buckets[key, default: []].append(idx)
            }
        }
        self.buckets = buckets
    }

    /// Candidate polygon indices near `coord` including neighboring grid cells for boundary stability.
    func candidateIndices(for coord: CLLocationCoordinate2D) -> [Int] {
        let (ix, iy) = cellIndices(for: coord)
        var seen = Set<Int>()
        var result: [Int] = []
        result.reserveCapacity(24)
        for ox in -1 ... 1 {
            for oy in -1 ... 1 {
                let key = Self.makeKey(ix + ox, iy + oy)
                guard let indices = buckets[key] else { continue }
                for i in indices where seen.insert(i).inserted {
                    result.append(i)
                }
            }
        }
        return result
    }

    private func cellIndices(for coord: CLLocationCoordinate2D) -> (Int, Int) {
        let ix = Int(floor(coord.latitude / cellSizeDegrees))
        let iy = Int(floor(coord.longitude / cellSizeDegrees))
        return (ix, iy)
    }

    private nonisolated static func makeKey(_ ix: Int, _ iy: Int) -> Int {
        // Fits Australian extents comfortably in Int.
        ix &* 200_000 &+ iy
    }

    private nonisolated static func latLonBounds(ring: [CLLocationCoordinate2D]) -> (
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double
    )? {
        guard let first = ring.first else { return nil }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for c in ring.dropFirst() {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        return (minLat, maxLat, minLon, maxLon)
    }

    private nonisolated static func overlappingCellKeys(
        bounding bbox: (
            minLat: Double,
            maxLat: Double,
            minLon: Double,
            maxLon: Double
        ),
        cellSize: Double
    ) -> [Int] {
        let minIx = Int(floor(bbox.minLat / cellSize))
        let maxIx = Int(floor(bbox.maxLat / cellSize))
        let minIy = Int(floor(bbox.minLon / cellSize))
        let maxIy = Int(floor(bbox.maxLon / cellSize))
        var keys: [Int] = []
        keys.reserveCapacity((maxIx - minIx + 1) * (maxIy - minIy + 1))
        for ix in minIx ... maxIx {
            for iy in minIy ... maxIy {
                keys.append(makeKey(ix, iy))
            }
        }
        return keys
    }
}

// MARK: - Thread-safe storage

private final class IndexedZoneStore: @unchecked Sendable {
    private let lock = NSLock()
    private var indexed: IndexedZones?

    func setZones(_ zones: IndexedZones?) {
        lock.lock()
        indexed = zones
        lock.unlock()
    }

    func snapshot() -> IndexedZones? {
        lock.lock()
        defer { lock.unlock() }
        return indexed
    }
}

private struct IndexedZones: Sendable {
    let polygons: [ZonePoly]
    let spatialIndex: MMMZoneSpatialIndex?
}

private final class LoadGate: @unchecked Sendable {
    private let lock = NSLock()
    private var ready = false
    private var waiters: [() -> Void] = []

    func notifyReady() {
        lock.lock()
        ready = true
        let callbacks = waiters
        waiters.removeAll()
        lock.unlock()
        callbacks.forEach { $0() }
    }

    func enqueueOrRunIfReady(_ body: @escaping () -> Void) {
        lock.lock()
        if ready {
            lock.unlock()
            body()
        } else {
            waiters.append(body)
            lock.unlock()
        }
    }

    func isReadyFlag() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return ready
    }
}

// MARK: - MMMZoneLookup

/// Loads SA1 polygons off the caller thread by default (see ``prepareLookupData()``).
public final class MMMZoneLookup: MMMZoneLookupProtocol, @unchecked Sendable {
    public static let shared = MMMZoneLookup()
    private static let resourceOverrideEnvironmentKey = "INVOICING_MMM_GEOJSON_PATH"

    private let store = IndexedZoneStore()
    private let loadGate = LoadGate()

    /// Use when tests or tooling need synchronous loading from a specific file.
    public init(resourceURL: URL) throws {
        let polys = try Self.loadPolygons(from: resourceURL)
        let indexed = Self.buildIndexedZones(polygons: polys)
        store.setZones(indexed)
        loadGate.notifyReady()
    }

    /// Begins background parsing of bundled or override GeoJSON; ``mmm(for:)`` returns nil until loading completes unless data is empty.
    public init() {
        guard let url = Self.defaultResourceURL() else {
            os_log(.error, "MMMZoneLookup: Could not resolve mmm_sa1.geojson from override path or bundle")
            store.setZones(IndexedZones(polygons: [], spatialIndex: nil))
            loadGate.notifyReady()
            return
        }
        let zoneStore = store
        let gate = loadGate
        Task.detached(priority: .utility) {
            let polys = (try? Self.loadPolygons(from: url)) ?? []
            let indexed = Self.buildIndexedZones(polygons: polys)
            zoneStore.setZones(indexed)
            os_log(.debug, "MMMZoneLookup: Loaded %d polygons for MMM zones", polys.count)
            gate.notifyReady()
        }
    }

    /// Await polygon data before performing billing / automation work that depends on MMM zones.
    public func prepareLookupData() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadGate.enqueueOrRunIfReady {
                continuation.resume()
            }
        }
    }

    /// Whether bundled polygons finished loading (or failed and fell back to empty).
    public var isLookupDataReady: Bool {
        loadGate.isReadyFlag()
    }

    public func mmm(for coord: CLLocationCoordinate2D) -> Int? {
        guard let indexed = store.snapshot(), !indexed.polygons.isEmpty else {
            return nil
        }

        let mapPoint = MKMapPoint(coord)

        if let spatialIndex = indexed.spatialIndex {
            let candidates = spatialIndex.candidateIndices(for: coord)
            for idx in candidates {
                let candidate = indexed.polygons[idx]
                guard candidate.bbox.contains(mapPoint) else { continue }
                if Self.contains(coord, in: candidate.ring) {
                    return candidate.mm
                }
            }
            return nil
        }

        let candidates = indexed.polygons.filter { $0.bbox.contains(mapPoint) }
        for candidate in candidates {
            if Self.contains(coord, in: candidate.ring) {
                return candidate.mm
            }
        }
        return nil
    }

    private static func buildIndexedZones(polygons: [ZonePoly]) -> IndexedZones {
        guard !polygons.isEmpty else {
            return IndexedZones(polygons: [], spatialIndex: nil)
        }
        let index = MMMZoneSpatialIndex(polygons: polygons)
        return IndexedZones(polygons: polygons, spatialIndex: index)
    }

    // MARK: - Helpers

    static func contains(_ c: CLLocationCoordinate2D, in ring: [CLLocationCoordinate2D]) -> Bool {
        var inside = false
        var j = ring.count - 1
        for i in 0 ..< ring.count {
            let xi = ring[i].longitude, yi = ring[i].latitude
            let xj = ring[j].longitude, yj = ring[j].latitude
            if ((yi > c.latitude) != (yj > c.latitude))
                && (c.longitude < (xj - xi) * (c.latitude - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    static func extractMMMCode(from props: String) -> Int {
        if let range = props.range(of: "\"MMM_CODE23\":") {
            let after = props[range.upperBound...]
            let codeStr = after.prefix { $0.isNumber }
            return Int(codeStr) ?? 0
        }
        return 0
    }

    fileprivate static func loadPolygons(from url: URL) throws -> [ZonePoly] {
        let data = try Data(contentsOf: url)
        let features = try MKGeoJSONDecoder().decode(data)
            .compactMap { $0 as? MKGeoJSONFeature }

        var polys: [ZonePoly] = []
        for feature in features {
            let props = String(data: feature.properties ?? Data(), encoding: .utf8) ?? ""
            let mm = extractMMMCode(from: props)

            for geometry in feature.geometry {
                if let poly = geometry as? MKPolygon {
                    polys.append(ZonePoly(bbox: poly.boundingMapRect, ring: poly.coordinates, mm: mm))
                } else if let multiPoly = geometry as? MKMultiPolygon {
                    for poly in multiPoly.polygons {
                        polys.append(ZonePoly(bbox: poly.boundingMapRect, ring: poly.coordinates, mm: mm))
                    }
                }
            }
        }

        return polys
    }

    private static func defaultResourceURL() -> URL? {
        if let overridePath = ProcessInfo.processInfo.environment[resourceOverrideEnvironmentKey],
           !overridePath.isEmpty {
            let overrideURL = URL(fileURLWithPath: overridePath)
            if FileManager.default.fileExists(atPath: overrideURL.path) {
                return overrideURL
            }

            os_log(
                .error,
                "MMMZoneLookup: Override path for %{public}@ does not exist: %{public}@",
                resourceOverrideEnvironmentKey,
                overridePath
            )
        }

        return Bundle.main.url(forResource: "mmm_sa1", withExtension: "geojson")
    }
}
