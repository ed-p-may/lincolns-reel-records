import ImageIO
@testable import LincolnReelRecords
import SwiftUI
import XCTest

@MainActor
final class CatchShareTests: XCTestCase {
    func testApprovedShareContentExcludesPrivateCatchAndAccountFields() throws {
        let content = try CatchShareContent(
            catchItem: catchItem(
                species: "Brook Trout",
                weight: 2.25,
                length: 17.5,
                location: "Green River"
            ),
            locale: Locale(identifier: "en_US_POSIX"),
            timeZone: XCTUnwrap(TimeZone(secondsFromGMT: 0))
        )

        XCTAssertEqual(content.species, "Brook Trout")
        XCTAssertEqual(content.weight, "2.2 lb")
        XCTAssertEqual(content.length, "17.5 in")
        XCTAssertEqual(content.spot, "Green River")
        XCTAssertEqual(content.caughtDate, "November 14, 2023")
        XCTAssertEqual(
            Mirror(reflecting: content).children.compactMap(\.label),
            ["species", "weight", "length", "spot", "caughtDate"]
        )
    }

    func testCompleteSparseAndLongCatchesRenderAtIntentionalDimensionsWithoutEXIF() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let photoURL = directory.appendingPathComponent("large-source.jpg")
        try fixturePhotoData(size: CGSize(width: 3600, height: 2400)).write(to: photoURL)
        let renderer = CatchShareRenderer()
        let fixtures = [
            (catchItem(species: "Largemouth Bass", weight: 8.5, length: 24, location: "Stockbridge Bowl"), photoURL),
            (catchItem(species: "Brook Trout", weight: nil, length: nil, location: nil), nil),
            (catchItem(
                species: "Largemouth Bass With An Exceptionally Long Display Name That Must Fit",
                weight: 2,
                length: nil,
                location: "North Shore By The Old Stone Landing With A Very Long Spot Name"
            ), photoURL)
        ]

        for (catchItem, photoURL) in fixtures {
            let data = try await renderer.render(
                content: CatchShareContent(
                    catchItem: catchItem,
                    locale: Locale(identifier: "en_US_POSIX"),
                    timeZone: XCTUnwrap(TimeZone(secondsFromGMT: 0))
                ),
                photoURL: photoURL
            )
            let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
            let properties = try XCTUnwrap(
                CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            )
            XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 1080)
            XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1350)
            XCTAssertNil(properties[kCGImagePropertyGPSDictionary])
            let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
            XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])
            XCTAssertNil(exif?[kCGImagePropertyExifUserComment])
            let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
            XCTAssertNil(tiff?[kCGImagePropertyTIFFMake])
            XCTAssertNil(tiff?[kCGImagePropertyTIFFModel])
            XCTAssertGreaterThan(data.count, 20000)
        }
    }

    func testTemporaryShareStoreRemovesCompletionArtifactAndPrunesExpiredFiles() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oldURL = directory.appendingPathComponent("old.jpg")
        try Data([1, 2, 3]).write(to: oldURL)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-TemporaryShareStore.maximumAge - 1)],
            ofItemAtPath: oldURL.path
        )
        let store = TemporaryShareStore(directory: directory)

        let artifact = try store.create(data: Data([4, 5, 6]), now: now)

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.url.path))
        store.remove(artifact)
        XCTAssertFalse(FileManager.default.fileExists(atPath: artifact.url.path))
    }

    private func catchItem(
        species: String,
        weight: Double?,
        length: Double?,
        location: String?
    ) -> CatchItem {
        CatchItem(
            id: UUID(),
            ownerID: UUID(),
            values: CatchValues(
                species: species,
                weight: weight,
                length: length,
                caughtAt: Date(timeIntervalSince1970: 1_700_000_000),
                location: location,
                coordinate: CatchCoordinate(latitude: 42, longitude: -73),
                conditions: CatchConditions(
                    airTemperatureF: 70,
                    skyCondition: .sunny,
                    waterTemperatureF: 62,
                    waterClarity: .clear
                ),
                lureText: "Private lure",
                rodReel: "Private rod",
                notes: "Private notes",
                released: true
            ),
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reel-records-share-tests-\(UUID().uuidString)", isDirectory: true)
    }

    private func fixturePhotoData(size: CGSize) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.systemBlue.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            UIImage(systemName: "fish.fill")?.withTintColor(.white).draw(
                in: CGRect(x: size.width * 0.35, y: size.height * 0.25, width: 800, height: 800)
            )
        }.jpegData(compressionQuality: 0.9)!
    }
}
