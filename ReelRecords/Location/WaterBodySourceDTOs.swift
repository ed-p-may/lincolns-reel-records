import Foundation

struct OverpassResponse: Decodable {
    let elements: [OverpassElement]
}

struct OverpassElement: Decodable {
    let type: String
    let id: Int64
    let lat: Double?
    let lon: Double?
    let center: OverpassCenter?
    let tags: [String: String]?

    var resolvedCoordinate: CatchCoordinate? {
        if let lat, let lon {
            return CatchCoordinate(latitude: lat, longitude: lon)
        }
        if let center {
            return CatchCoordinate(latitude: center.lat, longitude: center.lon)
        }
        return nil
    }
}

struct OverpassCenter: Decodable {
    let lat: Double
    let lon: Double
}

struct WikipediaSummaryResponse: Decodable {
    let type: String?
    let title: String
    let extract: String?
    let thumbnail: WikipediaImage?
    let originalImage: WikipediaImage?
    let contentURLs: WikipediaContentURLs?

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case extract
        case thumbnail
        case originalImage = "originalimage"
        case contentURLs = "content_urls"
    }
}

struct WikipediaImage: Decodable {
    let source: String
}

struct WikipediaContentURLs: Decodable {
    let desktop: WikipediaDesktopURL?
}

struct WikipediaDesktopURL: Decodable {
    let page: String?
}

struct INaturalistResponse: Decodable {
    let results: [INaturalistObservation]
}

struct INaturalistObservation: Decodable {
    let taxon: INaturalistTaxon?
    let photos: [INaturalistPhoto]?
    let user: INaturalistUser?
}

struct INaturalistTaxon: Decodable {
    let id: Int
    let name: String?
    let preferredCommonName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case preferredCommonName = "preferred_common_name"
    }
}

struct INaturalistPhoto: Decodable {
    let id: Int
    let url: String?
    let attribution: String?
    let licenseCode: String?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case attribution
        case licenseCode = "license_code"
    }
}

struct INaturalistUser: Decodable {
    let name: String?
    let login: String?
}

struct USGSResponse: Decodable {
    let value: USGSValue
}

struct USGSValue: Decodable {
    let timeSeries: [USGSTimeSeries]
}

struct USGSTimeSeries: Decodable {
    let sourceInfo: USGSSourceInfo
    let variable: USGSVariable
    let values: [USGSValueSet]
}

struct USGSSourceInfo: Decodable {
    let siteName: String
    let siteCode: [USGSSiteCode]
    let geoLocation: USGSGeoLocation?
}

struct USGSSiteCode: Decodable {
    let value: String
}

struct USGSGeoLocation: Decodable {
    let geogLocation: USGSGeogLocation?
}

struct USGSGeogLocation: Decodable {
    let latitude: Double
    let longitude: Double
}

struct USGSVariable: Decodable {
    let variableCode: [USGSVariableCode]
}

struct USGSVariableCode: Decodable {
    let value: String
}

struct USGSValueSet: Decodable {
    let value: [USGSMeasurement]
}

struct USGSMeasurement: Decodable {
    let value: String
    let dateTime: String?
}
