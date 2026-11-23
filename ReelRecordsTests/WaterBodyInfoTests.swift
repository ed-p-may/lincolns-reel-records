@testable import LincolnReelRecords
import XCTest

final class WaterBodyInfoTests: XCTestCase {
    private let stockbridgeCoord = CatchCoordinate(latitude: 42.3330, longitude: -73.3210)!

    func testLocalWaterHistoryMatchesByNameAndProximityAndComputesStats() {
        let senkoID = UUID()
        let selection = WaterBodySelection(
            id: "osm-way-1",
            name: "Stockbridge Bowl",
            waterType: .lake,
            coordinate: stockbridgeCoord,
            regionSubtitle: "Stockbridge, MA",
            wikipediaTag: nil
        )
        let catches = makeStockbridgeCatches(senkoID: senkoID)

        let history = LocalWaterHistory.summarize(
            catches: catches,
            tackleNames: [senkoID: "Green Pumpkin Senko"],
            for: selection
        )

        XCTAssertEqual(history.catchCount, 3)
        XCTAssertEqual(history.personalBestWeight, 4.2)
        XCTAssertEqual(history.personalBestLength, 19.5)
        XCTAssertEqual(history.topSpecies.first, "Largemouth Bass")
        XCTAssertEqual(history.topLures, ["Green Pumpkin Senko", "White Jig"])
        XCTAssertEqual(history.recentCatches.first?.id, catches[2].id)
    }

    private func makeStockbridgeCatches(senkoID: UUID) -> [CatchItem] {
        [
            CatchFixture(
                id: 1,
                species: "Largemouth Bass",
                weight: 4.2,
                length: 19.5,
                location: "Stockbridge Bowl North Shore",
                tackleItemID: senkoID,
                lureText: "Fallback"
            ).build(),
            CatchFixture(
                id: 2,
                species: "Smallmouth Bass",
                weight: 2.8,
                length: 16.0,
                location: "Unnamed Cove",
                coordinate: CatchCoordinate(latitude: 42.335, longitude: -73.32),
                lureText: "White Jig"
            ).build(),
            CatchFixture(
                id: 3,
                species: "Largemouth Bass",
                weight: 3.1,
                length: 17.0,
                location: "Stockbridge Bowl",
                coordinate: stockbridgeCoord,
                tackleItemID: senkoID
            ).build(),
            CatchFixture(
                id: 4,
                species: "Rainbow Trout",
                weight: 6.5,
                length: 24.0,
                location: "Lake Mansfield",
                coordinate: CatchCoordinate(latitude: 42.1951, longitude: -73.3544),
                lureText: "Spoon"
            ).build(),
            CatchFixture(
                id: 5,
                species: "Yellow Perch",
                weight: 1.0,
                length: 9.0,
                location: "Lake",
                coordinate: nil,
                lureText: "Minnow"
            ).build()
        ]
    }

    func testWaterBodyNameClassifierAcceptsWatersAndRejectsMountains() {
        XCTAssertTrue(WaterBodyNameClassifier.looksLikeWaterName("Stockbridge Bowl"))
        XCTAssertTrue(WaterBodyNameClassifier.looksLikeWaterName("Lake Mansfield"))
        XCTAssertTrue(WaterBodyNameClassifier.looksLikeWaterName("Housatonic River"))
        XCTAssertTrue(WaterBodyNameClassifier.looksLikeWaterName("Konkapot Brook"))
        XCTAssertTrue(WaterBodyNameClassifier.looksLikeWaterName("Otis Reservoir"))

        XCTAssertFalse(WaterBodyNameClassifier.looksLikeWaterName("Monument Mountain"))
        XCTAssertFalse(WaterBodyNameClassifier.looksLikeWaterName("Mount Greylock"))
        XCTAssertFalse(WaterBodyNameClassifier.looksLikeWaterName("Appalachian Trail"))
        XCTAssertFalse(WaterBodyNameClassifier.looksLikeWaterName("Beartown State Forest"))

        XCTAssertEqual(WaterBodyNameClassifier.classify(name: "Stockbridge Bowl"), .lake)
        XCTAssertEqual(WaterBodyNameClassifier.classify(name: "Housatonic River"), .river)
        XCTAssertEqual(WaterBodyNameClassifier.classify(name: "Goose Pond"), .pond)
        XCTAssertEqual(WaterBodyNameClassifier.classify(name: "Konkapot Brook"), .stream)
    }

    func testOverpassWaterParserDecodesAndRanksHintMatch() throws {
        let request = try XCTUnwrap(WaterBodySourceRequests.overpassResolve(at: stockbridgeCoord))
        let rawBody = try String(data: XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
        let decodedBody = try XCTUnwrap(rawBody.removingPercentEncoding)
        let isInRange = try XCTUnwrap(decodedBody.range(of: "is_in("))
        let unionRange = try XCTUnwrap(decodedBody.range(of: "\n(\n"))
        XCTAssertLessThan(isInRange.lowerBound, unionRange.lowerBound)

        let waterJSON = Data("""
        {
          "elements": [
            {
              "type": "area",
              "id": 3600001234,
              "tags": {
                "natural": "water", "water": "lake",
                "name": "Stockbridge Bowl", "wikipedia": "en:Stockbridge Bowl"
              }
            },
            {
              "type": "way", "id": 999,
              "center": { "lat": 42.334, "lon": -73.321 },
              "tags": { "natural": "water", "name": "Tiny Ditch" }
            }
          ]
        }
        """.utf8)

        let candidate = try XCTUnwrap(WaterBodySourceParsers.parseOverpassWaterCandidate(
            from: waterJSON,
            fallbackCoordinate: stockbridgeCoord,
            hintName: "Stockbridge Bowl"
        ))
        XCTAssertEqual(candidate.osmID, "osm-area-3600001234")
        XCTAssertEqual(candidate.name, "Stockbridge Bowl")
        XCTAssertEqual(candidate.waterType, .lake)
        XCTAssertEqual(candidate.wikipediaTag, "en:Stockbridge Bowl")
        XCTAssertEqual(candidate.coordinate, stockbridgeCoord)
    }

    func testOverpassAccessParserDeduplicatesAndLabelsPrivateRamps() throws {
        let rampJSON = Data("""
        {
          "elements": [
            {
              "type": "node", "id": 10, "lat": 42.3335, "lon": -73.3145,
              "tags": { "leisure": "slipway", "name": "Town Boat Ramp" }
            },
            {
              "type": "node", "id": 11, "lat": 42.3336, "lon": -73.3146,
              "tags": { "leisure": "slipway", "name": "Town Boat Ramp" }
            },
            {
              "type": "way", "id": 12, "center": { "lat": 42.3400, "lon": -73.3300 },
              "tags": { "leisure": "slipway", "access": "private" }
            }
          ]
        }
        """.utf8)

        let ramps = try WaterBodySourceParsers.parseOverpassAccessPoints(from: rampJSON, near: stockbridgeCoord)
        XCTAssertEqual(ramps.count, 2)
        XCTAssertEqual(ramps[0].name, "Town Boat Ramp")
        XCTAssertEqual(ramps[0].kind, "Boat Ramp")
        XCTAssertEqual(ramps[1].name, "Public Boat Ramp")
        XCTAssertEqual(ramps[1].kind, "Boat Ramp (Private)")
    }

    func testWikipediaParserExtractsSummaryAndRejectsDisambiguation() throws {
        let validJSON = Data("""
        {
          "type": "standard",
          "title": "Stockbridge Bowl",
          "extract": "Stockbridge Bowl is a lake in Berkshire County.",
          "thumbnail": { "source": "https://upload.wikimedia.org/thumb.jpg" },
          "content_urls": { "desktop": { "page": "https://en.wikipedia.org/wiki/Stockbridge_Bowl" } }
        }
        """.utf8)

        let summary = try XCTUnwrap(WaterBodySourceParsers.parseWikipediaSummary(from: validJSON))
        XCTAssertEqual(summary.extract, "Stockbridge Bowl is a lake in Berkshire County.")
        XCTAssertEqual(summary.pageURL?.absoluteString, "https://en.wikipedia.org/wiki/Stockbridge_Bowl")
        XCTAssertEqual(summary.photo?.source, "Wikipedia")

        let disambigJSON = Data("""
        { "type": "disambiguation", "title": "Long Pond", "extract": "Long Pond may refer to:" }
        """.utf8)
        XCTAssertNil(try WaterBodySourceParsers.parseWikipediaSummary(from: disambigJSON))
    }

    func testINaturalistParserAggregatesSpeciesAndAttributedCCPhotos() throws {
        let json = Data("""
        {
          "results": [
            {
              "taxon": { "id": 1, "name": "Micropterus salmoides", "preferred_common_name": "Largemouth Bass" },
              "user": { "name": "Jane Angler" },
              "photos": [
                {
                  "id": 101, "url": "https://static.inaturalist.org/photos/101/square.jpg",
                  "attribution": "(c) Jane Angler", "license_code": "cc-by"
                },
                {
                  "id": 102, "url": "https://static.inaturalist.org/photos/102/square.jpg",
                  "attribution": "All rights reserved", "license_code": null
                }
              ]
            },
            {
              "taxon": { "id": 1, "name": "Micropterus salmoides", "preferred_common_name": "Largemouth Bass" },
              "user": { "name": "", "login": "bob" },
              "photos": [
                {
                  "id": 103, "url": "https://static.inaturalist.org/photos/103/square.jpg",
                  "attribution": "", "license_code": "cc0"
                }
              ]
            },
            {
              "taxon": { "id": 2, "name": "Perca flavescens", "preferred_common_name": "Yellow Perch" },
              "user": { "login": "bob" }, "photos": []
            }
          ]
        }
        """.utf8)

        let parsed = try WaterBodySourceParsers.parseINaturalistObservations(from: json)
        XCTAssertEqual(parsed.species.map(\.commonName), ["Largemouth Bass", "Yellow Perch"])
        XCTAssertEqual(parsed.species.first?.observationCount, 2)
        XCTAssertEqual(parsed.photos.count, 2)
        XCTAssertEqual(parsed.photos.first?.license, "CC-BY")
        XCTAssertEqual(parsed.photos.first?.attribution, "(c) Jane Angler")
        XCTAssertEqual(parsed.photos.last?.attribution, "Photo by bob")
        XCTAssertTrue(parsed.photos.first?.thumbnailURL.absoluteString.contains("medium.jpg") == true)
    }

    func testUSGSGaugeParserConvertsTempAndIgnoresSentinels() throws {
        let json = Data("""
        {
          "value": {
            "timeSeries": [
              {
                "sourceInfo": {
                  "siteName": "HOUSATONIC RIVER NEAR GREAT BARRINGTON, MA",
                  "siteCode": [{ "value": "01197500" }],
                  "geoLocation": { "geogLocation": { "latitude": 42.23, "longitude": -73.35 } }
                },
                "variable": { "variableCode": [{ "value": "00060" }] },
                "values": [{ "value": [{ "value": "420", "dateTime": "2026-07-20T14:15:00.000-04:00" }] }]
              },
              {
                "sourceInfo": {
                  "siteName": "HOUSATONIC RIVER NEAR GREAT BARRINGTON, MA",
                  "siteCode": [{ "value": "01197500" }],
                  "geoLocation": { "geogLocation": { "latitude": 42.23, "longitude": -73.35 } }
                },
                "variable": { "variableCode": [{ "value": "00010" }] },
                "values": [{ "value": [{ "value": "20.0", "dateTime": "2026-07-20T14:15:00.000-04:00" }] }]
              },
              {
                "sourceInfo": {
                  "siteName": "HOUSATONIC RIVER NEAR GREAT BARRINGTON, MA",
                  "siteCode": [{ "value": "01197500" }],
                  "geoLocation": { "geogLocation": { "latitude": 42.23, "longitude": -73.35 } }
                },
                "variable": { "variableCode": [{ "value": "00065" }] },
                "values": [{ "value": [{ "value": "-999999", "dateTime": "2026-07-20T14:15:00.000-04:00" }] }]
              }
            ]
          }
        }
        """.utf8)

        let reading = try XCTUnwrap(try WaterBodySourceParsers.parseUSGSGaugeReading(
            from: json,
            near: XCTUnwrap(CatchCoordinate(latitude: 42.23, longitude: -73.35))
        ))
        XCTAssertEqual(reading.siteCode, "01197500")
        XCTAssertEqual(reading.dischargeCFS, 420)
        XCTAssertEqual(reading.waterTemperatureF ?? 0, 68.0, accuracy: 0.01)
        XCTAssertNil(reading.gaugeHeightFT)
        XCTAssertEqual(reading.compactFlowLabel, "420 cfs")
    }
}

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

    func testResolveWaterBodyRejectsNonWaterAndSharesCanonicalCacheKeyOffline() async throws {
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
            regionResolver: { _ in "Stockbridge, MA" }
        )
        let onlineResult = try await onlineClient.resolveWaterBody(
            at: stockbridgeCoord,
            hintName: "Stockbridge Bowl"
        )
        let online = try XCTUnwrap(onlineResult)
        XCTAssertEqual(online.regionSubtitle, "Stockbridge, MA")

        let offlineClient = WaterBodyInfoClient(
            loader: { _ in throw URLError(.notConnectedToInternet) }
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

        let dryLand = try await offlineClient.resolveWaterBody(at: stockbridgeCoord, hintName: nil)
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

private struct CatchFixture {
    let id: Int
    let species: String
    var weight: Double?
    var length: Double?
    var location: String?
    var coordinate: CatchCoordinate?
    var tackleItemID: UUID?
    var lureText: String?

    func build() -> CatchItem {
        CatchItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            ownerID: UUID(),
            values: CatchValues(
                species: species,
                weight: weight,
                length: length,
                caughtAt: Date(timeIntervalSince1970: TimeInterval(1_753_000_000 + id * 100)),
                location: location,
                coordinate: coordinate,
                tackleItemID: tackleItemID,
                lureText: lureText,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: Date(timeIntervalSince1970: TimeInterval(1_753_000_000 + id * 100)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(1_753_000_000 + id * 100)),
            deletedAt: nil,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
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
