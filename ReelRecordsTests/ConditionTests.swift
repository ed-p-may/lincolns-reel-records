@testable import LincolnReelRecords
import XCTest

final class ConditionTests: XCTestCase {
    func testSkyConditionStorageRoundTripsKnownAndUnknownValues() {
        for value in SkyCondition.knownValues {
            XCTAssertEqual(SkyCondition(storageValue: value.storageValue), value)
        }
        XCTAssertEqual(SkyCondition(storageValue: "hail"), .unknown("hail"))
        XCTAssertEqual(SkyCondition.unknown("hail").storageValue, "hail")
    }

    func testSkyConditionCodableUsesForwardCompatibleStorageString() throws {
        let encoded = try JSONEncoder().encode(SkyCondition.partlyCloudy)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"partly_cloudy\"")
        XCTAssertEqual(try JSONDecoder().decode(SkyCondition.self, from: Data("\"hail\"".utf8)), .unknown("hail"))
    }

    func testWaterClarityStorageRoundTripsKnownAndUnknownValues() {
        for value in WaterClarity.knownValues {
            XCTAssertEqual(WaterClarity(storageValue: value.storageValue), value)
        }
        XCTAssertEqual(WaterClarity(storageValue: "tea_colored"), .unknown("tea_colored"))
        XCTAssertEqual(WaterClarity.unknown("tea_colored").storageValue, "tea_colored")
    }

    func testWaterClarityCodableUsesForwardCompatibleStorageString() throws {
        let encoded = try JSONEncoder().encode(WaterClarity.stained)
        XCTAssertEqual(String(data: encoded, encoding: .utf8), "\"stained\"")
        XCTAssertEqual(
            try JSONDecoder().decode(WaterClarity.self, from: Data("\"tea_colored\"".utf8)),
            .unknown("tea_colored")
        )
    }

    func testWMOConditionMappingCoversSupportedGroupsAndDaylight() {
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 0, isDay: true), .sunny)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 1, isDay: false), .clearNight)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 2, isDay: true), .partlyCloudy)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 3, isDay: true), .overcast)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 75, isDay: true), .overcast)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 45, isDay: true), .fog)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 61, isDay: true), .rain)
        XCTAssertEqual(WMOConditionMapper.skyCondition(code: 99, isDay: false), .rain)
        XCTAssertNil(WMOConditionMapper.skyCondition(code: 200, isDay: true))
    }

    func testSuggestionFillsOnlyUntouchedEmptyFields() {
        var draft = ConditionEnrichmentDraft()
        let suggestion = WeatherSuggestion(
            airTemperatureF: 72,
            skyCondition: .partlyCloudy,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let applied = draft.apply(suggestion)

        XCTAssertEqual(applied.airTemperatureF, 72)
        XCTAssertEqual(applied.skyCondition, .partlyCloudy)
        XCTAssertEqual(draft.airSource, .suggested)
        XCTAssertEqual(draft.skySource, .suggested)
    }

    func testManualEditAndClearWinOverLateSuggestion() {
        var draft = ConditionEnrichmentDraft()
        draft.markAirTemperatureManual()
        draft.markSkyConditionManual()

        let applied = draft.apply(WeatherSuggestion(
            airTemperatureF: 72,
            skyCondition: .sunny,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))

        XCTAssertNil(applied.airTemperatureF)
        XCTAssertNil(applied.skyCondition)
        XCTAssertEqual(draft.airSource, .manual)
        XCTAssertEqual(draft.skySource, .manual)
    }

    func testExistingValuesWinOverSuggestion() {
        var draft = ConditionEnrichmentDraft(conditions: CatchConditions(
            airTemperatureF: 50,
            skyCondition: .fog,
            waterTemperatureF: nil,
            waterClarity: nil
        ))

        let applied = draft.apply(WeatherSuggestion(
            airTemperatureF: 72,
            skyCondition: .sunny,
            observedAt: Date(timeIntervalSince1970: 1_700_000_000)
        ))

        XCTAssertNil(applied.airTemperatureF)
        XCTAssertNil(applied.skyCondition)
        XCTAssertEqual(draft.airSource, .existing)
        XCTAssertEqual(draft.skySource, .existing)
    }
}

final class OpenMeteoClientTests: XCTestCase {
    private let coordinate = CatchCoordinate(latitude: 42.3169, longitude: -73.3226)!

    func testForecastRequestUsesUTCWindowAndFahrenheitHourlyFields() throws {
        let caughtAt = date("2026-07-19T14:20:00Z")
        let request = try XCTUnwrap(OpenMeteoClient.request(
            coordinate: coordinate,
            caughtAt: caughtAt,
            now: date("2026-07-19T12:00:00Z")
        ))
        let components = try XCTUnwrap(try URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let query = try Dictionary(uniqueKeysWithValues: XCTUnwrap(components.queryItems?.map { ($0.name, $0.value) }))

        XCTAssertEqual(components.host, "api.open-meteo.com")
        XCTAssertEqual(components.path, "/v1/forecast")
        XCTAssertEqual(query["hourly"], "temperature_2m,weather_code,is_day")
        XCTAssertEqual(query["temperature_unit"], "fahrenheit")
        XCTAssertEqual(query["timeformat"], "unixtime")
        XCTAssertEqual(query["timezone"], "GMT")
        XCTAssertEqual(query["start_date"], "2026-07-18")
        XCTAssertEqual(query["end_date"], "2026-07-20")
        XCTAssertEqual(request.timeoutInterval, 5)
    }

    func testOlderCatchUsesArchiveAndFarFutureMakesNoRequest() throws {
        let now = date("2026-07-19T12:00:00Z")
        let archive = try XCTUnwrap(OpenMeteoClient.request(
            coordinate: coordinate,
            caughtAt: date("2026-07-01T12:00:00Z"),
            now: now
        ))
        XCTAssertEqual(archive.url?.host(), "archive-api.open-meteo.com")
        XCTAssertEqual(archive.url?.path(), "/v1/archive")
        XCTAssertNil(OpenMeteoClient.request(
            coordinate: coordinate,
            caughtAt: date("2026-09-01T12:00:00Z"),
            now: now
        ))
    }

    func testFixtureChoosesClosestCompleteHourlySample() async throws {
        let caughtAt = date("2026-07-19T14:20:00Z")
        let fixture = Data("""
        {
          "hourly": {
            "time": [1784466000, 1784469600, 1784473200],
            "temperature_2m": [null, 71.5, 73.0],
            "weather_code": [1, 2, 3],
            "is_day": [1, 1, 1]
          }
        }
        """.utf8)
        let client = OpenMeteoClient { request in
            (fixture, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let suggestion = try await client.suggestion(
            at: coordinate,
            caughtAt: caughtAt,
            now: date("2026-07-19T12:00:00Z")
        )

        XCTAssertEqual(suggestion?.airTemperatureF, 71.5)
        XCTAssertEqual(suggestion?.skyCondition, .partlyCloudy)
        XCTAssertEqual(suggestion?.observedAt, Date(timeIntervalSince1970: 1_784_469_600))
    }

    func testDistantOrIncompleteFixtureProducesNoSuggestion() async throws {
        let fixture = Data("""
        {
          "hourly": {
            "time": [1700000000],
            "temperature_2m": [72.0],
            "weather_code": [null],
            "is_day": [1]
          }
        }
        """.utf8)
        let client = OpenMeteoClient { request in
            (fixture, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }

        let suggestion = try await client.suggestion(
            at: coordinate,
            caughtAt: date("2026-07-19T14:20:00Z"),
            now: date("2026-07-19T12:00:00Z")
        )

        XCTAssertNil(suggestion)
    }

    func testHTTPFailureIsExplicit() async {
        let client = OpenMeteoClient { request in
            (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
        }

        do {
            _ = try await client.suggestion(
                at: coordinate,
                caughtAt: date("2026-07-19T14:20:00Z"),
                now: date("2026-07-19T12:00:00Z")
            )
            XCTFail("Expected invalid response")
        } catch {
            XCTAssertEqual(error as? OpenMeteoError, .invalidResponse)
        }
    }

    func testRequestKeyCoalescesSubThresholdInputChanges() throws {
        let first = WeatherRequestKey(
            coordinate: coordinate,
            caughtAt: date("2026-07-19T14:20:00Z")
        )
        let second = try WeatherRequestKey(
            coordinate: XCTUnwrap(CatchCoordinate(latitude: 42.31691, longitude: -73.32259)),
            caughtAt: date("2026-07-19T14:24:00Z")
        )

        XCTAssertEqual(first, second)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
