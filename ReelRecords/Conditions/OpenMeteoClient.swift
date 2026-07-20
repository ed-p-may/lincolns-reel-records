import Foundation
import SwiftUI

struct WeatherSuggestion: Equatable, Sendable {
    let airTemperatureF: Double
    let skyCondition: SkyCondition?
    let observedAt: Date
}

struct WeatherRequestKey: Equatable, Hashable, Sendable {
    let latitudeE4: Int
    let longitudeE4: Int
    let caughtHour: Int64

    init(coordinate: CatchCoordinate, caughtAt: Date) {
        latitudeE4 = Int((coordinate.latitude * 10000).rounded())
        longitudeE4 = Int((coordinate.longitude * 10000).rounded())
        caughtHour = Int64((caughtAt.timeIntervalSince1970 / 3600).rounded())
    }
}

protocol WeatherSuggestionProviding: Sendable {
    func suggestion(
        at coordinate: CatchCoordinate,
        caughtAt: Date,
        now: Date
    ) async throws -> WeatherSuggestion?
}

extension WeatherSuggestionProviding {
    func suggestion(at coordinate: CatchCoordinate, caughtAt: Date) async throws -> WeatherSuggestion? {
        try await suggestion(at: coordinate, caughtAt: caughtAt, now: .now)
    }
}

struct UnavailableWeatherSuggestionProvider: WeatherSuggestionProviding {
    func suggestion(
        at _: CatchCoordinate,
        caughtAt _: Date,
        now _: Date
    ) async throws -> WeatherSuggestion? {
        nil
    }
}

extension EnvironmentValues {
    @Entry var weatherSuggestionProvider: any WeatherSuggestionProviding = UnavailableWeatherSuggestionProvider()
}

struct OpenMeteoClient: WeatherSuggestionProviding, Sendable {
    typealias Loader = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let maximumSampleDistance: TimeInterval = 90 * 60
    private let loader: Loader

    init(session: URLSession = .shared) {
        loader = { request in
            try await session.data(for: request)
        }
    }

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    func suggestion(
        at coordinate: CatchCoordinate,
        caughtAt: Date,
        now: Date
    ) async throws -> WeatherSuggestion? {
        guard let request = Self.request(coordinate: coordinate, caughtAt: caughtAt, now: now) else {
            return nil
        }
        let (data, response) = try await loader(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            throw OpenMeteoError.invalidResponse
        }
        let payload = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        return Self.closestSuggestion(in: payload.hourly, caughtAt: caughtAt)
    }

    static func request(
        coordinate: CatchCoordinate,
        caughtAt: Date,
        now: Date
    ) -> URLRequest? {
        guard let endpoint = OpenMeteoEndpoint(caughtAt: caughtAt, now: now) else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.path = endpoint.path
        let dates = requestDates(around: caughtAt)
        components.queryItems = [
            URLQueryItem(name: "latitude", value: posixDecimal(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: posixDecimal(coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "GMT"),
            URLQueryItem(name: "start_date", value: isoDate(dates.start)),
            URLQueryItem(name: "end_date", value: isoDate(dates.end))
        ]
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.cachePolicy = .returnCacheDataElseLoad
        return request
    }

    private static func closestSuggestion(
        in hourly: OpenMeteoHourlyResponse,
        caughtAt: Date
    ) -> WeatherSuggestion? {
        let count = min(
            hourly.time.count,
            hourly.temperature.count,
            hourly.weatherCode.count,
            hourly.isDay.count
        )
        let candidate = (0 ..< count)
            .compactMap { index -> (distance: TimeInterval, suggestion: WeatherSuggestion)? in
                guard let temperature = hourly.temperature[index], temperature.isFinite,
                      let code = hourly.weatherCode[index],
                      let isDay = hourly.isDay[index]
                else {
                    return nil
                }
                let observedAt = Date(timeIntervalSince1970: TimeInterval(hourly.time[index]))
                return (
                    abs(observedAt.timeIntervalSince(caughtAt)),
                    WeatherSuggestion(
                        airTemperatureF: temperature,
                        skyCondition: WMOConditionMapper.skyCondition(code: code, isDay: isDay == 1),
                        observedAt: observedAt
                    )
                )
            }
            .min { $0.distance < $1.distance }

        guard let candidate, candidate.distance <= maximumSampleDistance else { return nil }
        return candidate.suggestion
    }

    private static func requestDates(around date: Date) -> (start: Date, end: Date) {
        let calendar = utcCalendar()
        let day = calendar.startOfDay(for: date)
        return (
            calendar.date(byAdding: .day, value: -1, to: day)!,
            calendar.date(byAdding: .day, value: 1, to: day)!
        )
    }

    private static func isoDate(_ date: Date) -> String {
        let calendar = utcCalendar()
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    private static func posixDecimal(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

private enum OpenMeteoEndpoint {
    case forecast
    case archive

    private static let forecastHistoryDays = 5
    private static let forecastHorizonDays = 16

    init?(caughtAt: Date, now: Date) {
        let calendar = utcCalendar()
        let today = calendar.startOfDay(for: now)
        let caughtDay = calendar.startOfDay(for: caughtAt)
        let oldestForecast = calendar.date(byAdding: .day, value: -Self.forecastHistoryDays, to: today)!
        let latestForecast = calendar.date(byAdding: .day, value: Self.forecastHorizonDays, to: today)!

        if caughtDay < oldestForecast {
            self = .archive
        } else if caughtDay <= latestForecast {
            self = .forecast
        } else {
            return nil
        }
    }

    var host: String {
        switch self {
        case .forecast: "api.open-meteo.com"
        case .archive: "archive-api.open-meteo.com"
        }
    }

    var path: String {
        switch self {
        case .forecast: "/v1/forecast"
        case .archive: "/v1/archive"
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    let hourly: OpenMeteoHourlyResponse
}

private struct OpenMeteoHourlyResponse: Decodable {
    let time: [Int64]
    let temperature: [Double?]
    let weatherCode: [Int?]
    let isDay: [Int?]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature = "temperature_2m"
        case weatherCode = "weather_code"
        case isDay = "is_day"
    }
}

enum OpenMeteoError: Error, Equatable {
    case invalidResponse
}

private func utcCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
}
