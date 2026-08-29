import Foundation

struct WorldMapCoordinate: Sendable {
    let longitude: Double
    let latitude: Double
}

struct WorldMapPolygon: Sendable {
    let rings: [[WorldMapCoordinate]]
}

struct WorldMapShape: Identifiable, Sendable {
    let id: Int
    let geometryIdentifier: String
    let name: String
    let polygons: [WorldMapPolygon]
}

struct WorldMapMarker: Identifiable, Sendable {
    let id: Int
    let geometryIdentifier: String
    let name: String
    let coordinate: WorldMapCoordinate
}

struct WorldMapData: Sendable {
    let shapes: [WorldMapShape]
    let markers: [WorldMapMarker]
}

enum GeoJSONMapError: Error, LocalizedError {
    case missingResource(String)
    case unsupportedGeometry(String)
    case invalidCoordinate

    var errorDescription: String? {
        switch self {
        case let .missingResource(name):
            "The bundled map file \(name) is missing."
        case let .unsupportedGeometry(type):
            "The map contains unsupported \(type) geometry."
        case .invalidCoordinate:
            "The map contains an invalid coordinate."
        }
    }
}

enum GeoJSONMapService {
    static func load(bundle: Bundle = .main) async throws -> WorldMapData {
        guard let shapesURL = bundle.url(forResource: "WorldMap", withExtension: "geojson") else {
            throw GeoJSONMapError.missingResource("WorldMap.geojson")
        }
        guard let markersURL = bundle.url(forResource: "WorldMapTiny", withExtension: "geojson") else {
            throw GeoJSONMapError.missingResource("WorldMapTiny.geojson")
        }

        return try await Task.detached(priority: .userInitiated) {
            let decoder = JSONDecoder()
            let shapeCollection = try decoder.decode(
                GeoJSONFeatureCollection.self,
                from: Data(contentsOf: shapesURL)
            )
            let markerCollection = try decoder.decode(
                GeoJSONFeatureCollection.self,
                from: Data(contentsOf: markersURL)
            )

            let shapes: [WorldMapShape] = shapeCollection.features.enumerated().compactMap {
                element -> WorldMapShape? in
                let (index, feature) = element
                guard !feature.geometry.polygons.isEmpty else { return nil }
                return WorldMapShape(
                    id: index,
                    geometryIdentifier: feature.properties.geometryIdentifier,
                    name: feature.properties.name,
                    polygons: feature.geometry.polygons
                )
            }
            let markers: [WorldMapMarker] = markerCollection.features.enumerated().compactMap {
                element -> WorldMapMarker? in
                let (index, feature) = element
                guard let coordinate = feature.geometry.point else { return nil }
                return WorldMapMarker(
                    id: index,
                    geometryIdentifier: feature.properties.geometryIdentifier,
                    name: feature.properties.name,
                    coordinate: coordinate
                )
            }
            return WorldMapData(shapes: shapes, markers: markers)
        }.value
    }
}

private struct GeoJSONFeatureCollection: Decodable {
    let features: [GeoJSONFeature]
}

private struct GeoJSONFeature: Decodable {
    let properties: GeoJSONProperties
    let geometry: GeoJSONGeometry
}

private struct GeoJSONProperties: Decodable {
    let adminGeometryIdentifier: String?
    let isoGeometryIdentifier: String?
    let englishName: String?
    let fallbackName: String?

    var geometryIdentifier: String {
        if let isoGeometryIdentifier,
           !isoGeometryIdentifier.isEmpty,
           isoGeometryIdentifier != "-99" {
            return isoGeometryIdentifier
        }
        return adminGeometryIdentifier ?? ""
    }

    var name: String {
        englishName ?? fallbackName ?? geometryIdentifier
    }

    private enum CodingKeys: String, CodingKey {
        case adminGeometryIdentifier = "ADM0_A3"
        case isoGeometryIdentifier = "ISO_A3"
        case englishName = "NAME_EN"
        case fallbackName = "NAME"
    }
}

private struct GeoJSONGeometry: Decodable {
    let polygons: [WorldMapPolygon]
    let point: WorldMapCoordinate?

    private enum CodingKeys: String, CodingKey {
        case type
        case coordinates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "Polygon":
            let rawPolygons = try container.decode([[[Double]]].self, forKey: .coordinates)
            polygons = [try Self.makePolygon(from: rawPolygons)]
            point = nil
        case "MultiPolygon":
            let rawPolygons = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            polygons = try rawPolygons.map(Self.makePolygon)
            point = nil
        case "Point":
            let rawCoordinate = try container.decode([Double].self, forKey: .coordinates)
            polygons = []
            point = try Self.makeCoordinate(from: rawCoordinate)
        default:
            throw GeoJSONMapError.unsupportedGeometry(type)
        }
    }

    private static func makePolygon(from rawRings: [[[Double]]]) throws -> WorldMapPolygon {
        WorldMapPolygon(
            rings: try rawRings.map { ring in
                try ring.map(makeCoordinate)
            }
        )
    }

    private static func makeCoordinate(from values: [Double]) throws -> WorldMapCoordinate {
        guard values.count >= 2 else {
            throw GeoJSONMapError.invalidCoordinate
        }
        return WorldMapCoordinate(longitude: values[0], latitude: values[1])
    }
}
