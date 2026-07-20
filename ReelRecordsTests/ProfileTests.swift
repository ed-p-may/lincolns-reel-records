@testable import LincolnReelRecords
import SwiftData
import UIKit
import XCTest

@MainActor
final class ProfileTests: XCTestCase {
    func testFallbackNormalizationAndYearValidation() throws {
        let store = try makeStore()
        let account = account()
        let initial = try store.profileRepository.profile(account: account)
        XCTAssertEqual(initial.displayName, account.username)

        let saved = try store.profileRepository.update(
            ownerID: account.ownerID,
            values: ProfileValues(
                displayName: "  Lincoln Fisher  ",
                homeWater: "  Stockbridge Bowl ",
                anglerSince: 2019
            )
        )
        XCTAssertEqual(saved.displayName, "Lincoln Fisher")
        XCTAssertEqual(saved.homeWater, "Stockbridge Bowl")

        XCTAssertThrowsError(try store.profileRepository.update(
            ownerID: account.ownerID,
            values: ProfileValues(displayName: String(repeating: "x", count: 81), homeWater: nil, anglerSince: nil)
        ))
        XCTAssertThrowsError(try store.profileRepository.update(
            ownerID: account.ownerID,
            values: ProfileValues(displayName: nil, homeWater: String(repeating: "x", count: 121), anglerSince: nil)
        ))

        XCTAssertThrowsError(try store.profileRepository.update(
            ownerID: account.ownerID,
            values: ProfileValues(displayName: nil, homeWater: nil, anglerSince: 1899)
        )) { error in
            XCTAssertTrue(error is ProfileValidationError)
        }
    }

    func testSignatureSpeciesAndBreakdownReuseDashboardOrdering() {
        let ownerID = UUID()
        let catches = [
            catchItem(ownerID: ownerID, species: "Bass", weight: 2, date: Date(timeIntervalSince1970: 100)),
            catchItem(ownerID: ownerID, species: "Trout", weight: 5, date: Date(timeIntervalSince1970: 300)),
            catchItem(ownerID: ownerID, species: "bass", weight: 3, date: Date(timeIntervalSince1970: 200)),
            catchItem(ownerID: ownerID, species: "Trout", weight: 4, date: Date(timeIntervalSince1970: 250)),
            catchItem(ownerID: ownerID, species: "Perch", weight: nil, date: Date(timeIntervalSince1970: 400))
        ]

        let result = ProfileDerivation.insights(from: catches)
        XCTAssertEqual(result.totalCatches, 5)
        XCTAssertEqual(result.personalBest?.species, "Trout")
        XCTAssertEqual(result.speciesCount, 3)
        XCTAssertEqual(result.speciesBreakdown, [
            DashboardLabelStat(label: "Trout", count: 2),
            DashboardLabelStat(label: "bass", count: 2),
            DashboardLabelStat(label: "Perch", count: 1)
        ])
    }

    func testOfflineEditSynchronizesAndRecoversOnAnotherStore() async throws {
        let first = try makeStore()
        let account = account()
        let remote = InMemoryProfileRemoteStore(profile: remoteProfile(account: account))
        _ = try first.profileRepository.profile(account: account)
        _ = try first.profileRepository.update(
            ownerID: account.ownerID,
            values: ProfileValues(displayName: "Lincoln Fisher", homeWater: "Lake Mansfield", anglerSince: 2019)
        )
        XCTAssertEqual(try first.profileRepository.pendingCount(ownerID: account.ownerID), 1)
        XCTAssertEqual(try first.profileRepository.pendingMutation(ownerID: account.ownerID)?.expectedVersion, 1)

        await coordinator(store: first, remote: remote).sync(ownerID: account.ownerID)
        XCTAssertEqual(try first.profileRepository.pendingCount(ownerID: account.ownerID), 0)

        let second = try makeStore()
        _ = try second.profileRepository.profile(account: account)
        let recoveryCoordinator = coordinator(store: second, remote: remote)
        await recoveryCoordinator.sync(ownerID: account.ownerID)
        XCTAssertEqual(recoveryCoordinator.revision, 1)
        let recovered = try XCTUnwrap(second.profileRepository.profile(ownerID: account.ownerID))
        XCTAssertEqual(recovered.displayName, "Lincoln Fisher")
        XCTAssertEqual(recovered.homeWater, "Lake Mansfield")
    }

    func testAvatarReplaceAndRemoveCleanObsoleteRemoteObjects() async throws {
        let store = try makeStore()
        let account = account()
        let remote = InMemoryProfileRemoteStore(profile: remoteProfile(account: account))
        _ = try store.profileRepository.profile(account: account)

        let firstDraft = try await store.profileRepository.stageAsync(
            data: imageData(color: .systemGreen),
            sessionID: UUID()
        )
        let first = try store.profileRepository.update(
            ownerID: account.ownerID,
            values: .empty,
            avatarChange: .replace(firstDraft)
        )
        let firstPath = try XCTUnwrap(first.avatarStoragePath)
        await coordinator(store: store, remote: remote).sync(ownerID: account.ownerID)
        let firstExists = await remote.containsObject(path: firstPath)
        XCTAssertTrue(firstExists)

        try await verifyAvatarRecovery(account: account, remote: remote)

        let replacementDraft = try await store.profileRepository.stageAsync(
            data: imageData(color: .systemBlue),
            sessionID: UUID()
        )
        let replacement = try store.profileRepository.update(
            ownerID: account.ownerID,
            values: .empty,
            avatarChange: .replace(replacementDraft)
        )
        let replacementPath = try XCTUnwrap(replacement.avatarStoragePath)
        await coordinator(store: store, remote: remote).sync(ownerID: account.ownerID)
        let oldExists = await remote.containsObject(path: firstPath)
        let replacementExists = await remote.containsObject(path: replacementPath)
        XCTAssertFalse(oldExists)
        XCTAssertTrue(replacementExists)

        _ = try store.profileRepository.update(
            ownerID: account.ownerID,
            values: .empty,
            avatarChange: .remove
        )
        await coordinator(store: store, remote: remote).sync(ownerID: account.ownerID)
        let removedExists = await remote.containsObject(path: replacementPath)
        XCTAssertFalse(removedExists)
        XCTAssertNil(try store.profileRepository.profile(ownerID: account.ownerID)?.avatarStoragePath)
    }

    func testMetadataRetryDoesNotRepeatAvatarUpload() async throws {
        let store = try makeStore()
        let account = account()
        let remote = FailFirstProfileApplyStore(profile: remoteProfile(account: account))
        _ = try store.profileRepository.profile(account: account)
        let draft = try await store.profileRepository.stageAsync(
            data: imageData(color: .systemOrange),
            sessionID: UUID()
        )
        _ = try store.profileRepository.update(
            ownerID: account.ownerID,
            values: .empty,
            avatarChange: .replace(draft)
        )
        let coordinator = coordinator(store: store, remote: remote)

        await coordinator.sync(ownerID: account.ownerID)
        let firstCounts = await remote.counts()
        XCTAssertEqual(firstCounts.uploads, 1)
        XCTAssertEqual(try store.profileRepository.pendingCount(ownerID: account.ownerID), 1)
        await coordinator.sync(ownerID: account.ownerID)
        let finalCounts = await remote.counts()
        XCTAssertEqual(finalCounts.uploads, 1)
        XCTAssertEqual(finalCounts.applies, 2)
        XCTAssertEqual(try store.profileRepository.pendingCount(ownerID: account.ownerID), 0)
    }

    func testConflictRequiresExplicitKeepMineConfirmation() async throws {
        let store = try makeStore()
        let account = account()
        let remote = InMemoryProfileRemoteStore(profile: RemoteProfile(
            ownerID: account.ownerID,
            username: account.username,
            values: ProfileValues(displayName: "Other Device", homeWater: nil, anglerSince: nil),
            avatarStoragePath: nil,
            createdAt: .now,
            updatedAt: .now,
            version: 2
        ))
        _ = try store.profileRepository.profile(account: account)
        _ = try store.profileRepository.update(
            ownerID: account.ownerID,
            values: ProfileValues(displayName: "Keep Mine", homeWater: nil, anglerSince: nil)
        )
        let coordinator = coordinator(store: store, remote: remote)

        await coordinator.sync(ownerID: account.ownerID)
        XCTAssertEqual(try store.profileRepository.profile(ownerID: account.ownerID)?.syncState, .conflict)
        XCTAssertEqual(try store.profileRepository.pendingCount(ownerID: account.ownerID), 1)

        await coordinator.sync(ownerID: account.ownerID, confirmingConflicts: true)
        let remoteDisplayName = await remote.fetch(ownerID: account.ownerID)?.values.displayName
        XCTAssertEqual(remoteDisplayName, "Keep Mine")
        XCTAssertEqual(try store.profileRepository.pendingCount(ownerID: account.ownerID), 0)
    }

    func testSuspendingSyncWaitsForActiveFetchAndBlocksLaterRepopulation() async throws {
        let store = try makeStore()
        let account = account()
        _ = try store.profileRepository.profile(account: account)
        let initialRemote = RemoteProfile(
            ownerID: account.ownerID,
            username: account.username,
            values: ProfileValues(displayName: "Fetched Before Delete", homeWater: nil, anglerSince: nil),
            avatarStoragePath: nil,
            createdAt: .now,
            updatedAt: .now,
            version: 1
        )
        let remote = BlockingProfileFetchStore(profile: initialRemote)
        let coordinator = coordinator(store: store, remote: remote)
        let activeSync = Task { await coordinator.sync(ownerID: account.ownerID) }
        await remote.waitUntilFetchIsBlocked()
        let suspension = Task { await coordinator.suspendAndWait(ownerID: account.ownerID) }
        await Task.yield()
        await remote.releaseFetch()
        await activeSync.value
        await suspension.value

        await remote.seed(RemoteProfile(
            ownerID: account.ownerID,
            username: account.username,
            values: ProfileValues(displayName: "Must Not Repopulate", homeWater: nil, anglerSince: nil),
            avatarStoragePath: nil,
            createdAt: initialRemote.createdAt,
            updatedAt: .now,
            version: 2
        ))
        await coordinator.sync(ownerID: account.ownerID)

        let localName = try store.profileRepository.profile(ownerID: account.ownerID)?.displayName
        XCTAssertEqual(localName, "Fetched Before Delete")
    }

    func testAccountPurgeIsOwnerScoped() async throws {
        let store = try makeStore()
        let first = account()
        let second = account()
        _ = try store.profileRepository.profile(account: first)
        _ = try store.profileRepository.profile(account: second)
        _ = try store.catchRepository.create(NewCatch(ownerID: first.ownerID, values: catchValues(species: "Bass")))
        _ = try store.catchRepository.create(NewCatch(ownerID: second.ownerID, values: catchValues(species: "Trout")))

        XCTAssertEqual(try store.profileRepository.profile(ownerID: second.ownerID)?.displayName, second.username)
        XCTAssertEqual(try store.catchRepository.list(ownerID: second.ownerID).map(\.species), ["Trout"])
        let abandonedDraft = try await store.profileRepository.stageAsync(
            data: imageData(color: .systemRed),
            sessionID: UUID()
        )
        XCTAssertNotNil(store.profileRepository.fileURL(for: abandonedDraft))

        try store.profileRepository.purgeLocalAccountData(ownerID: first.ownerID)

        XCTAssertNil(try store.profileRepository.profile(ownerID: first.ownerID))
        XCTAssertTrue(try store.catchRepository.list(ownerID: first.ownerID).isEmpty)
        XCTAssertNotNil(try store.profileRepository.profile(ownerID: second.ownerID))
        XCTAssertEqual(try store.catchRepository.list(ownerID: second.ownerID).count, 1)
        XCTAssertNil(store.profileRepository.fileURL(for: abandonedDraft))
    }
}

private extension ProfileTests {
    struct TestStore {
        let container: ModelContainer
        let catchRepository: SwiftDataCatchRepository
        let profileRepository: SwiftDataProfileRepository
    }

    func makeStore() throws -> TestStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            CatchPhotoRecord.self,
            PhotoOutboxOperation.self,
            TackleItemRecord.self,
            TackleOutboxOperation.self,
            ProfileRecord.self,
            ProfileOutboxOperation.self,
            configurations: configuration
        )
        let root = FileManager.default.temporaryDirectory
            .appending(path: "reel-records-profile-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileStore = try PhotoFileStore(rootURL: root)
        return TestStore(
            container: container,
            catchRepository: SwiftDataCatchRepository(modelContext: container.mainContext),
            profileRepository: SwiftDataProfileRepository(modelContext: container.mainContext, fileStore: fileStore)
        )
    }

    func coordinator(store: TestStore, remote: any ProfileRemoteStore) -> SyncCoordinator {
        SyncCoordinator(
            repository: store.catchRepository,
            remoteStore: InMemoryCatchRemoteStore(),
            profileSync: ProfileSyncDependencies(repository: store.profileRepository, remoteStore: remote)
        )
    }

    func account() -> AccountSession {
        AccountSession(ownerID: UUID(), email: "angler@example.com", username: "angler", isOffline: false)
    }

    func remoteProfile(account: AccountSession) -> RemoteProfile {
        RemoteProfile(
            ownerID: account.ownerID,
            username: account.username,
            values: .empty,
            avatarStoragePath: nil,
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100),
            version: 1
        )
    }

    func catchValues(species: String) -> CatchValues {
        CatchValues(
            species: species,
            weight: nil,
            length: nil,
            caughtAt: .now,
            location: nil,
            lureText: nil,
            rodReel: nil,
            notes: nil,
            released: true
        )
    }

    func catchItem(ownerID: UUID, species: String, weight: Double?, date: Date) -> CatchItem {
        CatchItem(
            id: UUID(),
            ownerID: ownerID,
            values: CatchValues(
                species: species,
                weight: weight,
                length: nil,
                caughtAt: date,
                location: nil,
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: date,
            updatedAt: date,
            deletedAt: nil,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
    }

    func imageData(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 240))
        return renderer.image { context in
            color.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 320, height: 240))
        }.jpegData(compressionQuality: 0.9)!
    }

    func verifyAvatarRecovery(account: AccountSession, remote: InMemoryProfileRemoteStore) async throws {
        let recoveredStore = try makeStore()
        _ = try recoveredStore.profileRepository.profile(account: account)
        await coordinator(store: recoveredStore, remote: remote).sync(ownerID: account.ownerID)
        let recovered = try XCTUnwrap(recoveredStore.profileRepository.profile(ownerID: account.ownerID))
        XCTAssertNotNil(recoveredStore.profileRepository.fileURL(for: recovered))
        try recoveredStore.profileRepository.fileStore.remove(relativePath: recovered.avatarLocalRelativePath)
        XCTAssertNil(recoveredStore.profileRepository.fileURL(for: recovered))

        await coordinator(store: recoveredStore, remote: remote).sync(ownerID: account.ownerID)
        let redownloaded = try XCTUnwrap(recoveredStore.profileRepository.profile(ownerID: account.ownerID))
        XCTAssertNotNil(recoveredStore.profileRepository.fileURL(for: redownloaded))
    }
}

private actor FailFirstProfileApplyStore: ProfileRemoteStore {
    private let base: InMemoryProfileRemoteStore
    private var shouldFail = true
    private(set) var uploadCount = 0
    private(set) var applyCount = 0

    init(profile: RemoteProfile) {
        base = InMemoryProfileRemoteStore(profile: profile)
    }

    func upload(data: Data, path: String) async throws {
        uploadCount += 1
        await base.upload(data: data, path: path)
    }

    func apply(_ mutation: PendingProfileMutation) async throws -> ProfileMutationResult {
        applyCount += 1
        if shouldFail {
            shouldFail = false
            throw URLError(.networkConnectionLost)
        }
        return await base.apply(mutation)
    }

    func remove(paths: [String]) async throws {
        await base.remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await base.download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> RemoteProfile? {
        await base.fetch(ownerID: ownerID)
    }

    func counts() -> (uploads: Int, applies: Int) {
        (uploadCount, applyCount)
    }
}

private actor BlockingProfileFetchStore: ProfileRemoteStore {
    private let base: InMemoryProfileRemoteStore
    private var shouldBlock = true
    private var fetchContinuation: CheckedContinuation<Void, Never>?
    private var blockedWaiter: CheckedContinuation<Void, Never>?

    init(profile: RemoteProfile) {
        base = InMemoryProfileRemoteStore(profile: profile)
    }

    func upload(data: Data, path: String) async throws {
        await base.upload(data: data, path: path)
    }

    func apply(_ mutation: PendingProfileMutation) async throws -> ProfileMutationResult {
        await base.apply(mutation)
    }

    func remove(paths: [String]) async throws {
        await base.remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await base.download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> RemoteProfile? {
        if shouldBlock {
            shouldBlock = false
            await withCheckedContinuation { continuation in
                fetchContinuation = continuation
                blockedWaiter?.resume()
                blockedWaiter = nil
            }
        }
        return await base.fetch(ownerID: ownerID)
    }

    func waitUntilFetchIsBlocked() async {
        guard fetchContinuation == nil else { return }
        await withCheckedContinuation { blockedWaiter = $0 }
    }

    func releaseFetch() {
        fetchContinuation?.resume()
        fetchContinuation = nil
    }

    func seed(_ profile: RemoteProfile) async {
        await base.seed(profile)
    }
}
