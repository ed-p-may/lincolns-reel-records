import ImageIO
@testable import LincolnReelRecords
import XCTest

final class PhotoCaptureMetadataTests: XCTestCase {
    func testExifDateOffsetAndSignedGPSAreExtracted() {
        let properties: NSDictionary = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:08:10 06:42:15",
                kCGImagePropertyExifOffsetTimeOriginal: "-04:00"
            ],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 42.3169,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 73.3226,
                kCGImagePropertyGPSLongitudeRef: "W"
            ]
        ]

        let metadata = PhotoCaptureMetadata.extract(from: properties)

        XCTAssertEqual(metadata.capturedAt, utcDate(hour: 10, minute: 42, second: 15))
        XCTAssertEqual(metadata.coordinate, CatchCoordinate(latitude: 42.3169, longitude: -73.3226))
    }

    func testTiffDateUsesCurrentTimeZoneWhenExifOffsetIsUnavailable() {
        let properties: NSDictionary = [
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFDateTime: "2026:08:09 19:15:30"
            ]
        ]

        let metadata = PhotoCaptureMetadata.extract(from: properties)

        XCTAssertEqual(metadata.capturedAt, localDate(hour: 19, minute: 15, second: 30))
        XCTAssertNil(metadata.coordinate)
    }

    func testExifDateUsesCurrentTimeZoneWhenOffsetIsMalformed() {
        let properties: NSDictionary = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:08:09 19:15:30",
                kCGImagePropertyExifOffsetTimeOriginal: "unknown"
            ]
        ]

        let metadata = PhotoCaptureMetadata.extract(from: properties)

        XCTAssertEqual(metadata.capturedAt, localDate(hour: 19, minute: 15, second: 30))
    }

    func testTiffDateIsUsedWhenExifDateIsMalformed() {
        let properties: NSDictionary = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "not-a-date"
            ],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFDateTime: "2026:08:09 19:15:30"
            ]
        ]

        let metadata = PhotoCaptureMetadata.extract(from: properties)

        XCTAssertEqual(metadata.capturedAt, localDate(hour: 19, minute: 15, second: 30))
    }

    func testMalformedMetadataFallsBackWithoutPartialInvalidCoordinate() {
        let properties: NSDictionary = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "not-a-date"
            ],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 95,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 73,
                kCGImagePropertyGPSLongitudeRef: "W"
            ]
        ]

        let metadata = PhotoCaptureMetadata.extract(from: properties)

        XCTAssertEqual(metadata, .empty)
    }

    func testDefaultsAcceptFirstAvailableValueForEachField() throws {
        let firstDate = utcDate(hour: 10)
        let secondDate = utcDate(hour: 11)
        let coordinate = try XCTUnwrap(CatchCoordinate(latitude: 42.3, longitude: -73.3))
        var draft = PhotoMetadataDefaultsDraft()

        let first = draft.apply(PhotoCaptureMetadata(capturedAt: firstDate, coordinate: nil))
        let second = draft.apply(PhotoCaptureMetadata(capturedAt: secondDate, coordinate: coordinate))
        let third = draft.apply(PhotoCaptureMetadata(
            capturedAt: utcDate(hour: 12),
            coordinate: CatchCoordinate(latitude: 40, longitude: -70)
        ))

        XCTAssertEqual(first, AppliedPhotoMetadataDefaults(capturedAt: firstDate, coordinate: nil))
        XCTAssertEqual(second, AppliedPhotoMetadataDefaults(capturedAt: nil, coordinate: coordinate))
        XCTAssertEqual(third, AppliedPhotoMetadataDefaults(capturedAt: nil, coordinate: nil))
    }

    func testManualFieldsRejectPhotoMetadata() {
        var draft = PhotoMetadataDefaultsDraft()
        draft.markCapturedAtManual()
        draft.markCoordinateManual()

        let applied = draft.apply(PhotoCaptureMetadata(
            capturedAt: utcDate(hour: 10),
            coordinate: CatchCoordinate(latitude: 42.3, longitude: -73.3)
        ))

        XCTAssertEqual(applied, AppliedPhotoMetadataDefaults(capturedAt: nil, coordinate: nil))
    }

    private func utcDate(hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 10,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    private func localDate(hour: Int, minute: Int, second: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 9,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }
}
