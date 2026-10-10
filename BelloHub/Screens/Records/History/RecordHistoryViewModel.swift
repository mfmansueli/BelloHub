//
//  RecordHistoryViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of 4.7 RecordHistory: one client's treatment records newest first with their edit trail, the
/// corrections that change a locked record (the only way to change it, D9), her incidents and her photos.
@MainActor
@Observable
final class RecordHistoryViewModel {
    let clientID: UUID
    private(set) var client: Client?
    private(set) var items: [RecordHistoryItem] = []
    private(set) var incidents: [Incident] = []
    private(set) var photos: [Photo] = []
    private(set) var hasPhotoConsent = false
    private(set) var business: AgendaBusinessContext
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    private(set) var actionErrorMessage: String?
    private(set) var isWorking = false
    /// The correction (or edit) she is writing, nil when the sheet is closed.
    var draft: RecordCorrectionDraft?
    /// Why the draft cannot be saved yet, set only after she tried.
    private(set) var draftProblem: RecordEditRules.Problem?

    private let vault: VaultService
    private let profile: ProfileService
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private var imageCache = PhotoMemoryCache()

    init(
        clientID: UUID, vault: VaultService, profile: ProfileService, now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.clientID = clientID
        self.vault = vault
        self.profile = profile
        self.now = now
        self.makeID = makeID
        business = AgendaBusinessContext(profile: profile.profile)
    }

    // MARK: - Derived

    /// Her first name for the edit trail ("Created by Ana"). Read from the profile each time, not from the business
    /// snapshot taken at load: the profile may arrive after the screen (a launch straight into the history).
    var professionalName: String { profile.profile?.firstName ?? business.professionalFirstName }

    var pairs: [BeforeAfterPair] { PhotoComparisonRules.pairs(photos) }
    var timeline: [Photo] { PhotoComparisonRules.timeline(photos) }

    /// The record the open draft is about.
    var draftItem: RecordHistoryItem? {
        guard let draft else { return nil }
        return items.first { $0.id == draft.recordID }
    }

    /// Whether saving the draft edits the record (still open) or logs a correction (locked).
    var draftPath: RecordLockPolicy.EditPath {
        draftItem.map { RecordEditRules.path(for: $0.record, now: now()) } ?? .addCorrection
    }

    /// What the field says now, shown above the box she types in.
    var draftCurrentValue: String? {
        guard let draft, let item = draftItem else { return nil }
        return RecordEditRules.currentValue(of: draft.field, in: item.record, corrections: item.corrections)
    }

    // MARK: - Loading

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        business = AgendaBusinessContext(profile: profile.profile)
        guard let repository = vault.repository else {
            isLoading = false
            errorMessage = String(localized: "recordHistory.error.load")
            return
        }
        do {
            guard let loaded = try await repository.client(id: clientID) else {
                isMissing = true
                isLoading = false
                return
            }
            let records = try await repository.records(for: clientID)
            var corrections: [RecordCorrection] = []
            for record in records { corrections += try await repository.corrections(for: record.id) }
            client = loaded
            incidents = try await repository.incidents(for: clientID).sorted { $0.occurredAt > $1.occurredAt }
            photos = try await repository.photos(for: clientID)
            hasPhotoConsent = PhotoConsentRules.latestPhotoConsent(try await repository.consents(for: clientID)) != nil
            items = RecordHistoryBuilder.items(records: records, corrections: corrections, now: now())
            errorMessage = nil
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = String(localized: "recordHistory.error.load")
        }
    }

    // MARK: - Corrections

    func beginCorrection(for recordID: UUID) {
        draftProblem = nil
        actionErrorMessage = nil
        draft = RecordCorrectionDraft(recordID: recordID)
        syncDraftText()
    }

    /// Picking another field starts from what that field says now.
    func selectField(_ field: RecordCorrectableField) {
        draft?.field = field
        draftProblem = nil
        syncDraftText()
    }

    func cancelCorrection() {
        draft = nil
        draftProblem = nil
    }

    func saveCorrection() {
        Task { await saveCorrectionAsync() }
    }

    func saveCorrectionAsync() async {
        guard !isWorking, let draft, let item = draftItem, let repository = vault.repository else { return }
        let moment = now()
        if let problem = RecordEditRules.problem(
            for: draft, record: item.record, corrections: item.corrections, now: moment
        ) {
            draftProblem = problem
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch RecordEditRules.path(for: item.record, now: moment) {
            case .editDirectly:
                try await repository.save(draft.field.setting(
                    RecordEditRules.normalized(draft.newValue), in: item.record
                ))
            case .addCorrection:
                try await repository.addCorrection(RecordEditRules.correction(
                    id: makeID(), draft: draft, record: item.record, corrections: item.corrections, now: moment
                ))
            }
            self.draft = nil
            draftProblem = nil
            actionErrorMessage = nil
            await loadAsync()
        } catch {
            actionErrorMessage = String(localized: "recordHistory.error.save")
        }
    }

    func dismissActionError() {
        actionErrorMessage = nil
    }

    // MARK: - Photos

    /// The bytes of a photo, decrypted for this screen and kept only while it is open: every thumbnail, but full-size
    /// images only for the last few opened (`PhotoMemoryCache`), so a strip of 200 photos never holds 200 of them.
    func imageData(for photo: Photo) async -> PhotoData? {
        if let cached = imageCache.photo(photo.id) { return cached }
        guard let repository = vault.repository, let data = try? await repository.photoData(id: photo.id) else {
            return nil
        }
        imageCache.store(data, for: photo.id)
        return data
    }

    func visibilityOptions(for photo: Photo) -> [PhotoVisibility] {
        PhotoComparisonRules.visibilityOptions(for: photo, hasConsent: hasPhotoConsent)
    }

    func setVisibility(_ visibility: PhotoVisibility, of photo: Photo) {
        Task { await setVisibilityAsync(visibility, of: photo) }
    }

    func setVisibilityAsync(_ visibility: PhotoVisibility, of photo: Photo) async {
        guard !isWorking, visibility != photo.visibility, let repository = vault.repository else { return }
        let allowed = PhotoConsentRules.visibility(requested: visibility, hasConsent: hasPhotoConsent)
        guard allowed == visibility else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            guard let data = await imageData(for: photo) else {
                actionErrorMessage = String(localized: "recordHistory.error.save")
                return
            }
            var changed = photo
            changed.visibility = visibility
            try await repository.save(changed, data: data)
            actionErrorMessage = nil
            await loadAsync()
        } catch {
            actionErrorMessage = String(localized: "recordHistory.error.save")
        }
    }

    // MARK: - Private

    private func syncDraftText() {
        // Read first, then write: `draft?.newValue = draftCurrentValue` opens a write on `draft` while the getter reads
        // it, which the runtime reports as an exclusivity conflict and aborts.
        let current = draftCurrentValue ?? ""
        draft?.newValue = current
    }
}
