//
//  VisitDetailViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of one visit's details: everything its record says now (corrections applied), the day it
/// happened, its photos, incidents and linked documents, and its change history. Its own actions are completing or
/// correcting a field, setting the visit day and choosing what to copy into a new visit.
@MainActor
@Observable
final class VisitDetailViewModel: RecordCorrecting {
    let recordID: UUID
    private(set) var record: TreatmentRecord?
    private(set) var client: Client?
    private(set) var appointment: Appointment?
    private(set) var corrections: [RecordCorrection] = []
    private(set) var photos: [Photo] = []
    private(set) var incidents: [Incident] = []
    /// Her documents tied to this visit.
    private(set) var documents: [ConsentRecord] = []
    /// Every consent of the client, for the photo-sharing rule (a photo consent need not be tied to this visit).
    private(set) var photoConsents: [ConsentRecord] = []
    /// Her template's fields as empty answers, so a blank field can be completed later.
    private(set) var templateFields: [RecordFieldEntry] = []
    private(set) var isLoading = true
    private(set) var isMissing = false
    private(set) var errorMessage: String?
    // Set by the extensions in their own files, so not `private(set)`.
    var actionErrorMessage: String?
    var isWorking = false
    /// The correction (or edit) she is writing, nil when the sheet is closed.
    var draft: RecordCorrectionDraft?
    var draftProblem: RecordEditRules.Problem?

    let vault: VaultService
    let profile: ProfileService
    let now: @Sendable () -> Date
    let makeID: @Sendable () -> UUID
    private var thumbnails: [UUID: Data] = [:]
    private var fullImages = PhotoMemoryCache()
    private let listeners = TaskBag()

    init(
        recordID: UUID, vault: VaultService, profile: ProfileService, now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.recordID = recordID
        self.vault = vault
        self.profile = profile
        self.now = now
        self.makeID = makeID
    }

    // MARK: - Derived

    /// What the record says now.
    var values: RecordCurrentValues? {
        record.map { RecordCurrentValues(record: $0, corrections: corrections) }
    }

    var visitDate: RecordVisitDate? {
        guard let values else { return nil }
        return values.visitDate(appointments: appointment.map { [$0.id: $0] } ?? [:])
    }

    var state: VisitRecordState? {
        record.map { VisitRecordState.of($0, now: now()) }
    }

    var trail: [RecordTrailEntry] {
        record.map { RecordTrailBuilder.entries(for: $0, corrections: corrections, now: now()) } ?? []
    }

    /// Her first name for the change history ("Created by Ana").
    var professionalName: String { profile.profile?.firstName ?? "" }

    /// Every field she can complete or correct, her template's blank fields included.
    var editableFields: [RecordEditableField] {
        record.map { RecordEditableField.all(for: $0, templateFields: templateFields) } ?? []
    }

    /// Her template answers as they read now, including any added after the lock.
    var entries: [RecordFieldEntry] {
        values?.entries(templateFields: templateFields) ?? []
    }

    var hasPhotoConsent: Bool {
        PhotoConsentRules.latestPhotoConsent(photoConsents) != nil
    }

    // MARK: - Loading

    /// Loads now and again after any change to the vault (a photo added in the flow, a correction), so the details
    /// never show an old version. Safe to call again: a running watch is kept.
    func startListening() {
        guard listeners.isEmpty, let repository = vault.repository else {
            if vault.repository == nil { fail() }
            return
        }
        listeners.add([
            Task { [weak self] in
                for await _ in repository.clients() {
                    guard let self, !Task.isCancelled else { return }
                    await self.loadAsync()
                }
            }
        ])
    }

    func stopListening() {
        listeners.cancelAll()
    }

    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard let repository = vault.repository else { return fail() }
        do {
            guard let loaded = try await repository.record(id: recordID) else {
                isMissing = true
                isLoading = false
                return
            }
            record = loaded
            client = try await repository.client(id: loaded.clientID)
            if let appointmentID = loaded.appointmentID {
                appointment = try await repository.appointment(id: appointmentID)
            }
            corrections = try await repository.corrections(for: recordID)
            photos = try await repository.photos(for: loaded.clientID)
                .filter { $0.recordID == recordID }
                .sorted { $0.takenAt < $1.takenAt }
            incidents = try await repository.incidents(for: loaded.clientID).filter { $0.recordID == recordID }
            let consents = try await repository.consents(for: loaded.clientID)
            documents = consents.filter { $0.recordID == recordID }
            photoConsents = consents
            templateFields = makeTemplateFields()
            errorMessage = nil
            isMissing = false
            isLoading = false
        } catch {
            fail()
        }
    }

    // MARK: - Photos

    func thumbnail(for photo: Photo) async -> Data? {
        if let cached = thumbnails[photo.id] { return cached }
        guard let repository = vault.repository,
              let data = try? await repository.photoThumbnail(id: photo.id) else { return nil }
        thumbnails[photo.id] = data
        return data
    }

    func fullPhoto(for photo: Photo) async -> PhotoData? {
        if let cached = fullImages.photo(photo.id) { return cached }
        guard let repository = vault.repository, let data = try? await repository.photoData(id: photo.id) else {
            return nil
        }
        fullImages.store(data, for: photo.id)
        return data
    }

    // MARK: - Requests

    /// Continues a draft, or completes a record still open, in the visit flow.
    var continueRequest: TreatmentFlowRequest? {
        record.map {
            TreatmentFlowRequest(clientID: $0.clientID, appointmentID: $0.appointmentID, serviceID: $0.serviceID,
                                 recordID: $0.id)
        }
    }

    /// A new visit for the same client and service, with the parts she chose copied from this one.
    func reuseRequest(parts: Set<VisitReuse.Part>) -> TreatmentFlowRequest? {
        guard let record else { return nil }
        return TreatmentFlowRequest(clientID: record.clientID, serviceID: record.serviceID,
                                    base: VisitReuse(recordID: record.id, parts: parts))
    }

    // MARK: - Private

    func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("visitDetail.error.load"))
    }

    func failAction() {
        actionErrorMessage = String(interface: LocalizedStringResource("recordHistory.error.save"))
    }

    private func makeTemplateFields() -> [RecordFieldEntry] {
        let localization = AppLocalization(resolving: InterfaceLocale.current)
        let catalog = (try? ProfessionCatalog.loadBundled(localization: localization))
            ?? ProfessionCatalog(localization: localization.rawValue, status: "needs_review", entries: [])
        let fields = TreatmentFormFields.resolve(
            template: profile.template, professions: profile.profile?.professions ?? [], catalog: catalog,
            notesName: ""
        )
        return TreatmentFormFields.emptyEntries(fields)
    }
}
