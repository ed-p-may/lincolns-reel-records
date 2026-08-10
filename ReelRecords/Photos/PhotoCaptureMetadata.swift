import Foundation
import ImageIO
import SwiftUI

extension EnvironmentValues {
    @Entry var photoMetadataDefaultsFixture: PhotoCaptureMetadata?
}

struct PhotoCaptureMetadata: Equatable, Sendable {
    let capturedAt: Date?
    let coordinate: CatchCoordinate?

    static let empty = PhotoCaptureMetadata(capturedAt: nil, coordinate: nil)

    static func extract(from data: Data) -> PhotoCaptureMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0
        else { return .empty }
        return extract(from: source)
    }

    static func extract(from source: CGImageSource) -> PhotoCaptureMetadata {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) else { return .empty }
        return extract(from: properties as NSDictionary)
    }

    static func extract(from properties: NSDictionary) -> PhotoCaptureMetadata {
        let exif = properties[kCGImagePropertyExifDictionary] as? NSDictionary
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? NSDictionary
        let gps = properties[kCGImagePropertyGPSDictionary] as? NSDictionary
        return PhotoCaptureMetadata(
            capturedAt: captureDate(exif: exif, tiff: tiff),
            coordinate: coordinate(gps: gps)
        )
    }

    private static func captureDate(exif: NSDictionary?, tiff: NSDictionary?) -> Date? {
        if let original = string(exif?[kCGImagePropertyExifDateTimeOriginal]) {
            let offset = string(exif?[kCGImagePropertyExifOffsetTimeOriginal])
            if let date = parseDate(original, offset: offset) {
                return date
            }
        }
        guard let fallback = string(tiff?[kCGImagePropertyTIFFDateTime]) else { return nil }
        return parseDate(fallback, offset: nil)
    }

    private static func parseDate(_ value: String, offset: String?) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.isLenient = false
        if let offset {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
            if let date = formatter.date(from: value + offset) {
                return date
            }
        }
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.timeZone = .current
        return formatter.date(from: value)
    }

    private static func coordinate(gps: NSDictionary?) -> CatchCoordinate? {
        guard let gps,
              let latitude = number(gps[kCGImagePropertyGPSLatitude]),
              let longitude = number(gps[kCGImagePropertyGPSLongitude]),
              let signedLatitude = signedCoordinate(
                  latitude,
                  reference: string(gps[kCGImagePropertyGPSLatitudeRef]),
                  positive: "N",
                  negative: "S"
              ),
              let signedLongitude = signedCoordinate(
                  longitude,
                  reference: string(gps[kCGImagePropertyGPSLongitudeRef]),
                  positive: "E",
                  negative: "W"
              )
        else {
            return nil
        }
        return CatchCoordinate(latitude: signedLatitude, longitude: signedLongitude)
    }

    private static func signedCoordinate(
        _ value: Double,
        reference: String?,
        positive: String,
        negative: String
    ) -> Double? {
        guard value.isFinite else { return nil }
        guard let reference else { return value }
        switch reference.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case positive:
            return abs(value)
        case negative:
            return -abs(value)
        default:
            return nil
        }
    }

    private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let text = string(value) {
            return Double(text)
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let value as String:
            value
        case let value as NSString:
            value as String
        default:
            nil
        }
    }
}

struct PhotoMetadataDefaultsDraft: Equatable, Sendable {
    private var acceptsCapturedAt = true
    private var acceptsCoordinate = true

    mutating func markCapturedAtManual() {
        acceptsCapturedAt = false
    }

    mutating func markCoordinateManual() {
        acceptsCoordinate = false
    }

    mutating func apply(_ metadata: PhotoCaptureMetadata) -> AppliedPhotoMetadataDefaults {
        let capturedAt = acceptsCapturedAt ? metadata.capturedAt : nil
        let coordinate = acceptsCoordinate ? metadata.coordinate : nil
        if capturedAt != nil {
            acceptsCapturedAt = false
        }
        if coordinate != nil {
            acceptsCoordinate = false
        }
        return AppliedPhotoMetadataDefaults(capturedAt: capturedAt, coordinate: coordinate)
    }
}

struct AppliedPhotoMetadataDefaults: Equatable, Sendable {
    let capturedAt: Date?
    let coordinate: CatchCoordinate?
}
