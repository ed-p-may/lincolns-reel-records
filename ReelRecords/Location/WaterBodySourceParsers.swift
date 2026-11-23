import CoreLocation
import Foundation

struct OverpassWaterCandidate: Equatable, Sendable {
    let osmID: String
    let name: String
    let waterType: WaterBodyType
    let coordinate: CatchCoordinate
    let wikipediaTag: String?
}

struct WikipediaSummaryResult: Equatable, Sendable {
    let title: String
    let extract: String
    let pageURL: URL?
    let photo: WaterBodyPhoto?
}

struct INaturalistResult: Equatable, Sendable {
    let species: [WaterBodySpecies]
    let photos: [WaterBodyPhoto]
}

enum WaterBodySourceRequests {
    static let userAgent = "LincolnReelRecords/1.0 (iOS; +https://github.com/ed-p-may/lincolns-reel-records)"
    static let sourceTimeout: TimeInterval = 4

    static func overpassResolve(at coordinate: CatchCoordinate) -> URLRequest? {
        let lat = posixDecimal(coordinate.latitude)
        let lon = posixDecimal(coordinate.longitude)
        let query = """
        [out:json][timeout:4];
        is_in(\(lat),\(lon))->.a;
        (
          area.a["natural"="water"]["name"];
          area.a["landuse"="reservoir"]["name"];
          way(around:100,\(lat),\(lon))["natural"="water"]["name"];
          relation(around:100,\(lat),\(lon))["natural"="water"]["name"];
          way(around:100,\(lat),\(lon))["waterway"~"^(river|stream)$"]["name"];
          relation(around:100,\(lat),\(lon))["waterway"~"^(river|stream)$"]["name"];
          way(around:100,\(lat),\(lon))["landuse"="reservoir"]["name"];
        );
        out center tags 10;
        """
        return overpassPost(query: query)
    }

    static func overpassAccess(around coordinate: CatchCoordinate, radiusMeters: Int = 2500) -> URLRequest? {
        let lat = posixDecimal(coordinate.latitude)
        let lon = posixDecimal(coordinate.longitude)
        let query = """
        [out:json][timeout:4];
        (
          node(around:\(radiusMeters),\(lat),\(lon))["leisure"="slipway"];
          way(around:\(radiusMeters),\(lat),\(lon))["leisure"="slipway"];
        );
        out center tags 15;
        """
        return overpassPost(query: query)
    }

    static func wikipediaSummary(title: String) -> URLRequest? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.lowercased().hasPrefix("en:")
            ? String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmed
        guard !cleaned.isEmpty else { return nil }
        let underscored = cleaned.replacingOccurrences(of: " ", with: "_")
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/?#")
        guard let encoded = underscored.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)")
        else {
            return nil
        }
        return politeRequest(url: url)
    }

    static func iNaturalist(around coordinate: CatchCoordinate, radiusKM: Int = 3) -> URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.inaturalist.org"
        components.path = "/v1/observations"
        components.queryItems = [
            URLQueryItem(name: "lat", value: posixDecimal(coordinate.latitude)),
            URLQueryItem(name: "lng", value: posixDecimal(coordinate.longitude)),
            URLQueryItem(name: "radius", value: "\(radiusKM)"),
            URLQueryItem(name: "taxon_id", value: "47178"),
            URLQueryItem(name: "per_page", value: "30"),
            URLQueryItem(name: "quality_grade", value: "research,needs_id"),
            URLQueryItem(name: "order_by", value: "votes")
        ]
        guard let url = components.url else { return nil }
        return politeRequest(url: url)
    }

    static func usgsGauge(around coordinate: CatchCoordinate, deltaDegrees: Double = 0.025) -> URLRequest? {
        let minLon = max(-180, coordinate.longitude - deltaDegrees)
        let maxLon = min(180, coordinate.longitude + deltaDegrees)
        let minLat = max(-90, coordinate.latitude - deltaDegrees)
        let maxLat = min(90, coordinate.latitude + deltaDegrees)
        let bBox = [minLon, minLat, maxLon, maxLat].map(posixDecimal).joined(separator: ",")

        var components = URLComponents()
        components.scheme = "https"
        components.host = "waterservices.usgs.gov"
        components.path = "/nwis/iv/"
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "bBox", value: bBox),
            URLQueryItem(name: "parameterCd", value: "00060,00065,00010"),
            URLQueryItem(name: "siteStatus", value: "active")
        ]
        guard let url = components.url else { return nil }
        return politeRequest(url: url)
    }

    private static func overpassPost(query: String) -> URLRequest? {
        guard let url = URL(string: "https://overpass-api.de/api/interpreter") else { return nil }
        var request = politeRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [URLQueryItem(name: "data", value: query)]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        return request
    }

    private static func politeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: sourceTimeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func posixDecimal(_ value: Double) -> String {
        String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

enum WaterBodySourceParsers {
    private struct RankedCandidate {
        let candidate: OverpassWaterCandidate
        let score: Int
        let distance: CLLocationDistance
    }

    private struct SpeciesEntry {
        let common: String
        let scientific: String?
        let count: Int
    }

    private struct SiteAccumulator {
        let siteCode: String
        let siteName: String
        let distance: CLLocationDistance
        var dischargeCFS: Double?
        var gaugeHeightFT: Double?
        var waterTemperatureF: Double?
        var observedAt: Date?

        var hasMeasurement: Bool {
            dischargeCFS != nil || gaugeHeightFT != nil || waterTemperatureF != nil
        }
    }

    static func parseOverpassWaterCandidate(
        from data: Data,
        fallbackCoordinate: CatchCoordinate,
        hintName: String? = nil
    ) throws -> OverpassWaterCandidate? {
        let response = try JSONDecoder().decode(OverpassResponse.self, from: data)
        let normalizedHint = hintName.map(CatchDiscovery.normalized)
        let target = CLLocation(latitude: fallbackCoordinate.latitude, longitude: fallbackCoordinate.longitude)

        let ranked = response.elements.compactMap { element in
            rankedCandidate(for: element, fallback: fallbackCoordinate, target: target, hint: normalizedHint)
        }
        return ranked.min { first, second in
            first.score != second.score ? first.score > second.score : first.distance < second.distance
        }?.candidate
    }

    private static func rankedCandidate(
        for element: OverpassElement,
        fallback: CatchCoordinate,
        target: CLLocation,
        hint: String?
    ) -> RankedCandidate? {
        guard let tags = element.tags,
              let rawName = tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawName.isEmpty
        else {
            return nil
        }
        let isWater = tags["natural"] == "water"
            || tags["landuse"] == "reservoir"
            || tags["waterway"] == "river"
            || tags["waterway"] == "stream"
        guard isWater else { return nil }

        let coord = element.resolvedCoordinate ?? fallback
        let waterTag = tags["water"] ?? (tags["landuse"] == "reservoir" ? "reservoir" : nil)
        let type = WaterBodyNameClassifier.classify(
            name: rawName,
            osmWaterTag: waterTag,
            osmWaterwayTag: tags["waterway"]
        )
        let candidate = OverpassWaterCandidate(
            osmID: "osm-\(element.type)-\(element.id)",
            name: rawName,
            waterType: type,
            coordinate: coord,
            wikipediaTag: tags["wikipedia"]
        )
        var score = element.type == "area" ? 20 : 10
        if let hint, CatchDiscovery.normalized(rawName) == hint {
            score += 100
        }
        if tags["wikipedia"] != nil {
            score += 5
        }
        let distance = CLLocation(latitude: coord.latitude, longitude: coord.longitude).distance(from: target)
        return RankedCandidate(candidate: candidate, score: score, distance: distance)
    }

    static func parseOverpassAccessPoints(
        from data: Data,
        near coordinate: CatchCoordinate
    ) throws -> [WaterBodyAccessPoint] {
        let response = try JSONDecoder().decode(OverpassResponse.self, from: data)
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var seenKeys: Set<String> = []
        var items: [(point: WaterBodyAccessPoint, distance: CLLocationDistance)] = []

        for element in response.elements {
            guard let coord = element.resolvedCoordinate else { continue }
            let tags = element.tags ?? [:]
            let rawName = tags["name"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = rawName?.isEmpty == false ? rawName! : "Public Boat Ramp"
            let key = "\(CatchDiscovery.normalized(name))-\(Int(coord.latitude * 1000))-\(Int(coord.longitude * 1000))"
            guard seenKeys.insert(key).inserted else { continue }

            let kind = tags["access"] == "private" ? "Boat Ramp (Private)" : "Boat Ramp"
            let point = WaterBodyAccessPoint(
                id: "osm-\(element.type)-\(element.id)",
                name: name,
                kind: kind,
                coordinate: coord
            )
            let distance = CLLocation(latitude: coord.latitude, longitude: coord.longitude).distance(from: origin)
            items.append((point, distance))
        }
        return items.sorted { $0.distance < $1.distance }.prefix(8).map(\.point)
    }

    static func parseWikipediaSummary(from data: Data) throws -> WikipediaSummaryResult? {
        let payload = try JSONDecoder().decode(WikipediaSummaryResponse.self, from: data)
        guard payload.type?.lowercased() != "disambiguation",
              let extract = payload.extract?.trimmingCharacters(in: .whitespacesAndNewlines),
              !extract.isEmpty
        else {
            return nil
        }
        let pageURL = payload.contentURLs?.desktop?.page.flatMap(URL.init(string:))
        var photo: WaterBodyPhoto?
        if let thumbString = payload.thumbnail?.source, let thumbURL = URL(string: thumbString) {
            let fullURL = payload.originalImage.flatMap { URL(string: $0.source) } ?? thumbURL
            photo = WaterBodyPhoto(
                id: "wiki-\(payload.title)",
                thumbnailURL: thumbURL,
                fullURL: fullURL,
                attribution: "Wikimedia Commons / Wikipedia",
                license: "CC BY-SA",
                source: "Wikipedia"
            )
        }
        return WikipediaSummaryResult(title: payload.title, extract: extract, pageURL: pageURL, photo: photo)
    }

    static func parseINaturalistObservations(from data: Data) throws -> INaturalistResult {
        let payload = try JSONDecoder().decode(INaturalistResponse.self, from: data)
        var speciesMap: [Int: SpeciesEntry] = [:]
        var photos: [WaterBodyPhoto] = []
        var seenPhotoIDs: Set<String> = []

        for observation in payload.results {
            accumulateSpecies(from: observation.taxon, into: &speciesMap)
            if photos.count < 6 {
                appendPhotos(from: observation, into: &photos, seenIDs: &seenPhotoIDs)
            }
        }

        let species = speciesMap
            .sorted { first, second in
                first.value.count != second.value.count
                    ? first.value.count > second.value.count
                    : CatchDiscovery.alphabeticallyPrecedes(first.value.common, second.value.common)
            }
            .prefix(12)
            .map { taxonID, entry in
                WaterBodySpecies(
                    id: "inat-\(taxonID)",
                    commonName: entry.common,
                    scientificName: entry.scientific,
                    observationCount: entry.count,
                    source: "iNaturalist"
                )
            }
        return INaturalistResult(species: Array(species), photos: photos)
    }

    private static func accumulateSpecies(from taxon: INaturalistTaxon?, into map: inout [Int: SpeciesEntry]) {
        guard let taxon else { return }
        let common = taxon.preferredCommonName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let scientific = taxon.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = common?.isEmpty == false ? common! : (scientific ?? "")
        guard !displayName.isEmpty else { return }
        if let existing = map[taxon.id] {
            map[taxon.id] = SpeciesEntry(
                common: existing.common,
                scientific: existing.scientific,
                count: existing.count + 1
            )
        } else {
            map[taxon.id] = SpeciesEntry(common: displayName, scientific: scientific, count: 1)
        }
    }

    private static func appendPhotos(
        from observation: INaturalistObservation,
        into photos: inout [WaterBodyPhoto],
        seenIDs: inout Set<String>
    ) {
        for obsPhoto in observation.photos ?? [] where photos.count < 6 {
            guard let license = obsPhoto.licenseCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !license.isEmpty,
                  let rawURL = obsPhoto.url,
                  let thumbURL = URL(string: rawURL.replacingOccurrences(of: "square", with: "medium"))
            else {
                continue
            }
            let photoID = "inat-\(obsPhoto.id)"
            guard seenIDs.insert(photoID).inserted else { continue }
            let fullURL = URL(string: rawURL.replacingOccurrences(of: "square", with: "large")) ?? thumbURL
            let rawAttr = obsPhoto.attribution?.trimmingCharacters(in: .whitespacesAndNewlines)
            let userName = nonEmptyTrimmed(observation.user?.name)
            let userLogin = nonEmptyTrimmed(observation.user?.login)
            let fallbackUser = userName ?? userLogin ?? "iNaturalist contributor"
            let attribution = rawAttr?.isEmpty == false ? rawAttr! : "Photo by \(fallbackUser)"
            photos.append(WaterBodyPhoto(
                id: photoID,
                thumbnailURL: thumbURL,
                fullURL: fullURL,
                attribution: attribution,
                license: license.uppercased(),
                source: "iNaturalist"
            ))
        }
    }

    static func parseUSGSGaugeReading(
        from data: Data,
        near coordinate: CatchCoordinate
    ) throws -> RiverGaugeReading? {
        let payload = try JSONDecoder().decode(USGSResponse.self, from: data)
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var sites: [String: SiteAccumulator] = [:]

        for series in payload.value.timeSeries {
            mergeUSGSSeries(series, origin: origin, into: &sites)
        }

        let best = sites.values
            .filter(\.hasMeasurement)
            .min { first, second in
                if (first.dischargeCFS != nil) != (second.dischargeCFS != nil) {
                    return first.dischargeCFS != nil
                }
                return first.distance < second.distance
            }

        guard let best else { return nil }
        return RiverGaugeReading(
            siteCode: best.siteCode,
            siteName: best.siteName,
            dischargeCFS: best.dischargeCFS,
            gaugeHeightFT: best.gaugeHeightFT,
            waterTemperatureF: best.waterTemperatureF,
            observedAt: best.observedAt
        )
    }

    private static func mergeUSGSSeries(
        _ series: USGSTimeSeries,
        origin: CLLocation,
        into sites: inout [String: SiteAccumulator]
    ) {
        guard let siteCode = series.sourceInfo.siteCode.first?.value,
              let paramCode = series.variable.variableCode.first?.value,
              let latest = series.values.first?.value.last,
              let rawNumber = Double(latest.value),
              rawNumber.isFinite,
              rawNumber > -999_000
        else {
            return
        }
        let distance = series.sourceInfo.geoLocation?.geogLocation.map { geo in
            CLLocation(latitude: geo.latitude, longitude: geo.longitude).distance(from: origin)
        } ?? .greatestFiniteMagnitude

        var acc = sites[siteCode] ?? SiteAccumulator(
            siteCode: siteCode,
            siteName: series.sourceInfo.siteName,
            distance: distance
        )
        switch paramCode {
        case "00060" where rawNumber >= 0: acc.dischargeCFS = rawNumber
        case "00065": acc.gaugeHeightFT = rawNumber
        case "00010": acc.waterTemperatureF = (rawNumber * 9 / 5) + 32
        default: return
        }
        if let parsedDate = parseUSGSDate(latest.dateTime) {
            let isNewer = acc.observedAt.map { parsedDate > $0 } ?? true
            if isNewer {
                acc.observedAt = parsedDate
            }
        }
        sites[siteCode] = acc
    }

    private static func parseUSGSDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
    }

    private static func nonEmptyTrimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
