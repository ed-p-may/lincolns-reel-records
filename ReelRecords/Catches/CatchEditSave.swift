import Foundation

struct CatchEditSnapshot: Equatable, Sendable {
    var catchItem: CatchItem
    var photos: [CatchPhotoSnapshot]?
}

struct CatchEditSaveResult: Equatable, Sendable {
    let updatedCatch: CatchItem?
    let didMutate: Bool
}

struct CatchEditSaveRequest {
    let ownerID: UUID
    let snapshot: CatchEditSnapshot?
    let submittedValues: CatchValues
    let orderedPhotoIDs: [UUID]
    let draftPhotos: [DraftPhoto]
    let photoSessionID: UUID
    let catchRepository: SwiftDataCatchRepository
    let photoRepository: SwiftDataCatchPhotoRepository
    let tackleRepository: SwiftDataTackleRepository
}

enum CatchEditSaveError: LocalizedError {
    case photosFailed(savedCatch: CatchItem?, underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .photosFailed(savedCatch, underlying):
            if savedCatch != nil {
                "The catch is saved locally, but its photos were not attached: "
                    + underlying.localizedDescription
            } else {
                underlying.localizedDescription
            }
        }
    }
}

@MainActor
enum CatchEditSave {
    static func persist(_ request: CatchEditSaveRequest) throws -> CatchEditSaveResult {
        if let snapshot = request.snapshot {
            return try saveEdit(request, snapshot: snapshot)
        }
        return try createNew(request)
    }

    private static func createNew(_ request: CatchEditSaveRequest) throws -> CatchEditSaveResult {
        try request.tackleRepository.validateSelectableSelection(
            itemID: request.submittedValues.tackleItemID,
            unchangedFrom: nil,
            ownerID: request.ownerID
        )
        let catchItem = try request.catchRepository.create(
            NewCatch(ownerID: request.ownerID, values: request.submittedValues)
        )
        do {
            try request.photoRepository.saveOrder(
                catchID: catchItem.id,
                ownerID: request.ownerID,
                orderedIDs: request.orderedPhotoIDs,
                drafts: request.draftPhotos
            )
            try request.photoRepository.discardDrafts(sessionID: request.photoSessionID)
        } catch {
            throw CatchEditSaveError.photosFailed(savedCatch: catchItem, underlying: error)
        }
        return CatchEditSaveResult(updatedCatch: catchItem, didMutate: true)
    }

    private struct EditPlan {
        let snapshot: CatchEditSnapshot
        let normalizedSubmitted: CatchValues
        let normalizedOpening: CatchValues
        let catchChanged: Bool
        let photosChanged: Bool
    }

    private static func saveEdit(
        _ request: CatchEditSaveRequest,
        snapshot: CatchEditSnapshot
    ) throws -> CatchEditSaveResult {
        let normalizedSubmitted = try request.catchRepository.normalizedValues(request.submittedValues)
        let normalizedOpening = try request.catchRepository.normalizedValues(snapshot.catchItem.values)
        let plan = EditPlan(
            snapshot: snapshot,
            normalizedSubmitted: normalizedSubmitted,
            normalizedOpening: normalizedOpening,
            catchChanged: normalizedSubmitted != normalizedOpening,
            photosChanged: hasPhotoChanges(
                openingPhotos: snapshot.photos,
                orderedPhotoIDs: request.orderedPhotoIDs,
                draftPhotos: request.draftPhotos
            )
        )

        if !plan.catchChanged, !plan.photosChanged {
            try? request.photoRepository.discardDrafts(sessionID: request.photoSessionID)
            return CatchEditSaveResult(updatedCatch: nil, didMutate: false)
        }

        try verifyEditPreconditions(request, plan: plan)
        return try applyEdit(request, plan: plan)
    }

    private static func verifyEditPreconditions(_ request: CatchEditSaveRequest, plan: EditPlan) throws {
        let catchID = plan.snapshot.catchItem.id
        if plan.catchChanged {
            try request.tackleRepository.validateSelectableSelection(
                itemID: plan.normalizedSubmitted.tackleItemID,
                unchangedFrom: plan.snapshot.catchItem.tackleItemID,
                ownerID: request.ownerID
            )
            try request.catchRepository.verifyUnchanged(
                id: catchID,
                ownerID: request.ownerID,
                expectedValues: plan.normalizedOpening
            )
        } else {
            try request.catchRepository.verifyActive(id: catchID, ownerID: request.ownerID)
        }

        if plan.photosChanged {
            guard let openingPhotos = plan.snapshot.photos else {
                throw CatchPhotoRepositoryError.concurrentChange(catchID)
            }
            try request.photoRepository.verifyUnchanged(
                catchID: catchID,
                ownerID: request.ownerID,
                expectedSnapshot: openingPhotos
            )
        }
    }

    private static func applyEdit(_ request: CatchEditSaveRequest, plan: EditPlan) throws -> CatchEditSaveResult {
        let catchID = plan.snapshot.catchItem.id
        var savedCatch: CatchItem?
        if plan.catchChanged {
            savedCatch = try request.catchRepository.update(
                id: catchID,
                ownerID: request.ownerID,
                values: plan.normalizedSubmitted,
                expectedValues: plan.normalizedOpening
            )
        }

        if plan.photosChanged {
            do {
                try request.photoRepository.saveOrder(
                    catchID: catchID,
                    ownerID: request.ownerID,
                    orderedIDs: request.orderedPhotoIDs,
                    drafts: request.draftPhotos,
                    expectedSnapshot: plan.snapshot.photos
                )
                try request.photoRepository.discardDrafts(sessionID: request.photoSessionID)
            } catch {
                throw CatchEditSaveError.photosFailed(savedCatch: savedCatch, underlying: error)
            }
        } else {
            try? request.photoRepository.discardDrafts(sessionID: request.photoSessionID)
        }

        return CatchEditSaveResult(updatedCatch: savedCatch, didMutate: true)
    }

    private static func hasPhotoChanges(
        openingPhotos: [CatchPhotoSnapshot]?,
        orderedPhotoIDs: [UUID],
        draftPhotos: [DraftPhoto]
    ) -> Bool {
        if let openingPhotos {
            return !draftPhotos.isEmpty || orderedPhotoIDs != openingPhotos.map(\.id)
        }
        return !draftPhotos.isEmpty || !orderedPhotoIDs.isEmpty
    }
}
