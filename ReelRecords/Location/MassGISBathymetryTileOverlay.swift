import Foundation
import MapKit

final class MassGISBathymetryTileOverlay: MKTileOverlay, @unchecked Sendable {
    static let tileURLTemplate =
        "https://tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/arcgis/rest/services/"
            + "Inland_Bathymetry/MapServer/tile/{z}/{y}/{x}"

    static let minZoom = 11
    static let maxZoom = 18

    // Massachusetts geographic bounding box (with small margin for border ponds)
    static let massachusettsMinLatitude = 41.2
    static let massachusettsMaxLatitude = 42.9
    static let massachusettsMinLongitude = -73.55
    static let massachusettsMaxLongitude = -69.9

    /// Valid 1x1 transparent PNG returned for out-of-bounds, 404, or offline tiles.
    static let emptyTilePNG = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82
    ])

    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? Self.makeCachingSession()
        super.init(urlTemplate: Self.tileURLTemplate)
        canReplaceMapContent = false
        minimumZ = Self.minZoom
        maximumZ = Self.maxZoom
        tileSize = CGSize(width: 256, height: 256)
    }

    static func overlayAlpha(for style: CatchMapStyle) -> CGFloat {
        switch style {
        case .standard:
            0.78
        case .hybrid, .satellite:
            0.68
        }
    }

    static func tileURL(column: Int, row: Int, zoom: Int) -> URL {
        let string = "https://tiles.arcgis.com/tiles/hGdibHYSPO59RG1h/arcgis/rest/services/"
            + "Inland_Bathymetry/MapServer/tile/\(zoom)/\(row)/\(column)"
        return URL(string: string)!
    }

    static func shouldFetchTile(column: Int, row: Int, zoom: Int) -> Bool {
        guard (minZoom ... maxZoom).contains(zoom) else {
            return false
        }
        let tileCount = 1 << zoom
        guard column >= 0, column < tileCount, row >= 0, row < tileCount else {
            return false
        }
        let tilesPerAxis = Double(tileCount)
        let westLon = Double(column) / tilesPerAxis * 360.0 - 180.0
        let eastLon = Double(column + 1) / tilesPerAxis * 360.0 - 180.0
        let northLat = atan(sinh(.pi * (1.0 - 2.0 * Double(row) / tilesPerAxis))) * 180.0 / .pi
        let southLat = atan(sinh(.pi * (1.0 - 2.0 * Double(row + 1) / tilesPerAxis))) * 180.0 / .pi

        let latOverlaps = northLat >= massachusettsMinLatitude && southLat <= massachusettsMaxLatitude
        let lonOverlaps = eastLon >= massachusettsMinLongitude && westLon <= massachusettsMaxLongitude
        return latOverlaps && lonOverlaps
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        Self.tileURL(column: path.x, row: path.y, zoom: path.z)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, (any Error)?) -> Void) {
        guard Self.shouldFetchTile(column: path.x, row: path.y, zoom: path.z) else {
            result(Self.emptyTilePNG, nil)
            return
        }
        let resultBox = TileResultBox(handler: result)
        var request = URLRequest(url: url(forTilePath: path))
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 10

        session.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data,
                  !data.isEmpty
            else {
                resultBox.handler(Self.emptyTilePNG, nil)
                return
            }
            resultBox.handler(data, nil)
        }.resume()
    }

    private static func makeCachingSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 25 * 1024 * 1024,
            diskPath: "MassGISBathymetryTileCache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }
}

private struct TileResultBox: @unchecked Sendable {
    let handler: (Data?, (any Error)?) -> Void
}
