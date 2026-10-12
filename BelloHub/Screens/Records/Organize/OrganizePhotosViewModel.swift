//
//  OrganizePhotosViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of "Organize photos": the client's photos that belong to no visit, and the visits she can place
/// each one in. Nothing is placed automatically, not even when a photo and a visit share a day: she decides.
@MainActor
@Observable
final class OrganizePhotosViewModel {
    let clientID: UUID
    private(set) var photos: [Photo] = []
    /// Her visits, newest first, as the choices for a photo.
    private(set) var visits: [VisitSummary] = []
    private(set) var isLoading = true
    private(set) var errorMessage: String?
    private(set) var isWorking = false

    private let vault: VaultService
    private let now: @Sendable () -> Date
    private var thumbnails: [UUID: Data] = [:]

    init(clientID: UUID, vault: VaultService, now: @escaping @Sendable () -> Date = { Date() }) {
        self.clientID = clientID
        self.vault = vault
        self.now = now
    }

    func loadAsync() async {
        guard let repository = vault.repository else { return fail() }
        do {
            let input = ClientTimelineBuilder.Input(
                records: try await repository.records(for: clientID),
                appointments: try await repository.appointments(for: clientID),
                photos: try await repository.photos(for: clientID)
            )
            let timeline = ClientTimelineBuilder.make(input, now: now(), list: { $0.joined(separator: ", ") })
            photos = timeline.unlinkedPhotos
            visits = timeline.visits
            errorMessage = nil
            isLoading = false
        } catch {
            fail()
        }
    }

    func thumbnail(for photo: Photo) async -> Data? {
        if let cached = thumbnails[photo.id] { return cached }
        guard let repository = vault.repository,
              let data = try? await repository.photoThumbnail(id: photo.id) else { return nil }
        thumbnails[photo.id] = data
        return data
    }

    /// Places a photo in a visit. The photo keeps its own day and who can see it; only its visit changes.
    func link(_ photo: Photo, to visit: VisitSummary) {
        Task { await linkAsync(photo, to: visit) }
    }

    func linkAsync(_ photo: Photo, to visit: VisitSummary) async {
        guard !isWorking, let repository = vault.repository else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let data = try await repository.photoData(id: photo.id)
            var linked = photo
            linked.recordID = visit.id
            try await repository.save(linked, data: data)
            await loadAsync()
        } catch {
            errorMessage = String(interface: LocalizedStringResource("organizePhotos.error.save"))
        }
    }

    private func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("organizePhotos.error.load"))
    }
}
