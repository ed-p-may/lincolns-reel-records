@testable import LincolnReelRecords
import XCTest

final class WaterBodyInfoClientTests: XCTestCase {
    private let stockbridgeCoord = CatchCoordinate(latitude: 42.3330, longitude: -73.3210)!
    private let stockbridgeSelection = WaterBodySelection(
        id: "osm-way-42",
        name: "Stockbridge Bowl",
        waterType: .lake,
        coordinate: CatchCoordinate(latitude: 42.3330, longitude: -73.3210)!,
        regionSubtitle: "Stockbridge, MA",
        wikipediaTag: "en:Stockbridge Bowl"
    )

    func testPartialSourceDegradationAndCacheHit() async throws {
        let cacheDir = makeTempCacheDir()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let cache = WaterBodyInfoCache(directoryURL: cacheDir)
        let callCount = LockedCounter()
        let baseDate = Date(timeIntervalSince1970: 1_753_000_000)
        let client = WaterBodyInfoClient(
            loader: Self.partialSuccessLoader(counter: callCount),
            cache: cache,
            now: { baseDate }
        )

        let first = try await client.fetchInfo(for: stockbridgeSelection, forceRefresh: false)
        XCTAssertNil(first.overview)
        XCTAssertEqual(first.species.map(\.commonName), ["Northern Pike"])
        XCTAssertFalse(first.isFromOfflineCache)
        let callsAfterFirst = callCount.value
        XCTAssertGreaterThan(callsAfterFirst, 0)

        let cachedHit = try await client.fetchInfo(for: stockbridgeSelection, forceRefresh: false)
        XCTAssertEqual(cachedHit.species.map(\.commonName), ["Northern Pike"])
        XCTAssertEqual(callCount.value, callsAfterFirst)
    }

    func testOfflineFallbackReturnsStaleCacheAndThrowsWhenUncached() async throws {
        let cacheDir = makeTempCacheDir()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let cache = WaterBodyInfoCache(directoryURL: cacheDir)
        let baseDate = Date(timeIntervalSince1970: 1_753_000_000)
        let onlineClient = WaterBodyInfoClient(
            loader: Self.partialSuccessLoader(counter: LockedCounter()),
            cache: cache,
            now: { baseDate }
        )
        _ = try await onlineClient.fetchInfo(for: stockbridgeSelection, forceRefresh: false)

        let staleDate = baseDate.addingTimeInterval(WaterBodyInfoCache.staticInfoTTL + 3600)
        let offlineClient = WaterBodyInfoClient(
            loader: { _ in throw URLError(.notConnectedToInternet) },
            cache: cache,
            now: { staleDate }
        )
        let staleFallback = try await offlineClient.fetchInfo(for: stockbridgeSelection, forceRefresh: false)
        XCTAssertTrue(staleFallback.isFromOfflineCache)
        XCTAssertEqual(staleFallback.species.map(\.commonName), ["Northern Pike"])

        let uncached = WaterBodySelection(
            id: "osm-way-999",
            name: "Uncached Pond",
            waterType: .pond,
            coordinate: stockbridgeCoord,
            regionSubtitle: nil,
            wikipediaTag: nil
        )
        do {
            _ = try await offlineClient.fetchInfo(for: uncached, forceRefresh: false)
            XCTFail("Expected offlineOrUnavailable error for uncached water when offline")
        } catch let error as WaterBodyInfoError {
            XCTAssertEqual(error, .offlineOrUnavailable)
        }
    }

    func testPartialRefreshPreservesCachedSectionsAndOfflineReopensLongPressedPond() async throws {
        let cacheDir = makeTempCacheDir()
        defer { try? FileManager.default.removeItem(at: cacheDir) }

        let cache = WaterBodyInfoCache(directoryURL: cacheDir)
        let baseDate = Date(timeIntervalSince1970: 1_753_000_000)

        let onlineClient = WaterBodyInfoClient(
            loader: { request in
                let url = request.url!
                if url.host == "overpass-api.de" {
                    let body = Data("""
                    {
                      "elements": [{
                        "type": "area", "id": 3600001234,
                        "tags": { "natural": "water", "water": "lake", "name": "Stockbridge Bowl" }
                      }]
                    }
                    """.utf8)
                    return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
                }
                return try await Self.partialSuccessLoader(counter: LockedCounter())(request)
            },
            cache: cache,
            now: { baseDate }
        )
        let onlineResolved = try await onlineClient.resolveWaterBody(at: stockbridgeCoord, hintName: nil)
        let selection = try XCTUnwrap(onlineResolved)
        let first = try await onlineClient.fetchInfo(for: selection, forceRefresh: false)
        XCTAssertEqual(first.species.map(\.commonName), ["Northern Pike"])

        let partialRefreshClient = WaterBodyInfoClient(
            loader: { request in
                let url = request.url!
                if url.host == "overpass-api.de" {
                    return (
                        Data(#"{"elements":[]}"#.utf8),
                        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                    )
                }
                throw URLError(.timedOut)
            },
            cache: cache,
            now: { baseDate.addingTimeInterval(3600) }
        )
        let merged = try await partialRefreshClient.fetchInfo(for: selection, forceRefresh: true)
        XCTAssertEqual(merged.species.map(\.commonName), ["Northern Pike"])

        let offlineClient = WaterBodyInfoClient(
            loader: { _ in throw URLError(.notConnectedToInternet) },
            cache: cache,
            now: { baseDate.addingTimeInterval(7200) }
        )
        let reopened = try await offlineClient.resolveWaterBody(at: stockbridgeCoord, hintName: nil)
        XCTAssertEqual(reopened?.id, selection.id)
    }

    func testResolveWaterBodyRejectsNonWaterAndSharesCanonicalCacheKeyOffline() async throws {
        let cacheDir = makeTempCacheDir()
        defer { try? FileManager.default.removeItem(at: cacheDir) }
        let cache = WaterBodyInfoCache(directoryURL: cacheDir)

        let onlineClient = WaterBodyInfoClient(
            loader: { request in
                let body = Data("""
                {
                  "elements": [{
                    "type": "area", "id": 3600001234,
                    "tags": { "natural": "water", "water": "lake", "name": "Stockbridge Bowl" }
                  }]
                }
                """.utf8)
                return (body, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            },
            cache: cache,
            regionResolver: { _ in "Stockbridge, MA" }
        )
        let onlineResult = try await onlineClient.resolveWaterBody(
            at: stockbridgeCoord,
            hintName: "Stockbridge Bowl"
        )
        let online = try XCTUnwrap(onlineResult)
        XCTAssertEqual(online.regionSubtitle, "Stockbridge, MA")

        let offlineClient = WaterBodyInfoClient(
            loader: { _ in throw URLError(.notConnectedToInternet) },
            cache: cache
        )
        let mountain = try await offlineClient.resolveWaterBody(at: stockbridgeCoord, hintName: "Monument Mountain")
        XCTAssertNil(mountain)

        let offlineResult = try await offlineClient.resolveWaterBody(
            at: stockbridgeCoord,
            hintName: "Stockbridge Bowl"
        )
        let offlineLake = try XCTUnwrap(offlineResult)
        XCTAssertEqual(offlineLake.id, online.id)
        XCTAssertEqual(offlineLake.waterType, .lake)

        let dryCoord = try XCTUnwrap(CatchCoordinate(latitude: 42.10, longitude: -73.10))
        let dryLand = try await offlineClient.resolveWaterBody(at: dryCoord, hintName: nil)
        XCTAssertNil(dryLand)
    }

    private func makeTempCacheDir() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("WaterBodyCacheTest-\(UUID().uuidString)", isDirectory: true)
    }

    private static func partialSuccessLoader(counter: LockedCounter) -> WaterBodyInfoClient.Loader {
        { request in
            counter.increment()
            let url = request.url!
            if url.host == "en.wikipedia.org" {
                return (Data(), HTTPURLResponse(url: url, statusCode: 500, httpVersion: nil, headerFields: nil)!)
            }
            if url.host == "api.inaturalist.org" {
                let body = Data("""
                {
                  "results": [{
                    "taxon": { "id": 7, "name": "Esox lucius", "preferred_common_name": "Northern Pike" },
                    "photos": []
                  }]
                }
                """.utf8)
                return (body, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let emptyOverpass = Data(#"{"elements":[]}"#.utf8)
            return (emptyOverpass, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}
