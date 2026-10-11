//
//  TreatmentFlowFramingReferenceTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The camera's framing reference (routine item 11): which photo's bytes the ViewModel hands the camera, read from the
/// vault into memory only.
@MainActor
@Suite("TreatmentFlowViewModel framing reference", .serialized)
struct TreatmentFlowFramingReferenceTests {
    /// A photo of an earlier visit: its kind, its bytes and how many days ago it was taken.
    private struct EarlierPhoto {
        let kind: PhotoKind
        let bytes: Data
        let daysAgo: Int

        init(_ kind: PhotoKind, _ byte: UInt8, daysAgo: Int) {
            self.kind = kind
            bytes = Data([byte])
            self.daysAgo = daysAgo
        }
    }

    private func makeModel(
        earlierPhotos: [EarlierPhoto] = []
    ) async throws -> (TreatmentFlowViewModel, any ClientRecordRepository) {
        let world = try await ClientsWorld.make()
        let client = makeClient(name: "Ana Costa")
        _ = try await world.repository.save(client)
        for earlier in earlierPhotos {
            let photo = Photo(
                id: UUID(), clientID: client.id, recordID: UUID(), takenAt: TestClock.days(-earlier.daysAgo),
                kind: earlier.kind, visibility: .professionalOnly
            )
            try await world.repository.save(photo, data: PhotoData(image: earlier.bytes, thumbnail: Data([0])))
        }
        let model = TreatmentFlowViewModel(
            request: TreatmentFlowRequest(clientID: client.id), repository: world.repository, profile: world.profile,
            photoProcessing: FakePhotoProcessing(), fallbackServiceName: "Treatment", notesName: "Observations",
            recommendationName: "Recommendation", now: { TestClock.now }
        )
        await model.load()
        return (model, world.repository)
    }

    @Test("A first visit with no photo has no reference: the camera works as before")
    func noPhotoNoReference() async throws {
        let (model, _) = try await makeModel()
        #expect(await model.framingReference(for: .before) == nil)
    }

    @Test("The last visit's 'before' is the reference for today's 'before', in full size")
    func earlierVisit() async throws {
        let (model, _) = try await makeModel(earlierPhotos: [
            EarlierPhoto(.before, 1, daysAgo: 60), EarlierPhoto(.before, 2, daysAgo: 30),
            EarlierPhoto(.after, 3, daysAgo: 29)
        ])
        #expect(await model.framingReference(for: .before) == Data([2]))
    }

    @Test("Once today's 'before' is taken, it is the reference for today's 'after'")
    func thisVisitPairs() async throws {
        let (model, _) = try await makeModel(earlierPhotos: [EarlierPhoto(.after, 3, daysAgo: 30)])
        await model.addPhoto(Data([9]), kind: .before)

        #expect(await model.framingReference(for: .after) == Data([9]))
    }
}
