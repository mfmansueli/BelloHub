//
//  TreatmentFlowViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The state of the whole treatment flow (5.1 to 5.9): who the visit is for, the questions of her template, what she
/// has
/// answered, the transcript and the proposals of the voice path, the saved record and what follows it. The voice,
/// review, photo and next-session parts are in extensions of this class (one file each); the rules they apply are pure
/// types in `Support/`. Nothing here reaches the network: the vault is the only store.
///
/// Properties the extensions change are plain `var`s with an internal setter, because `private(set)` would stop an
/// extension in another file from writing them; screens only read them.
@MainActor
@Observable
final class TreatmentFlowViewModel {
    enum LoadState: Equatable {
        case loading
        case ready
        /// The client was deleted or merged away while the flow was opening.
        case clientMissing
        case failed
    }

    /// What went wrong, for the screen to say in her language.
    enum Failure: Equatable {
        case save
        case photo
        case organize
    }

    let request: TreatmentFlowRequest
    var path: [TreatmentFlowStep] = []
    private(set) var loadState = LoadState.loading
    private(set) var client: Client?
    private(set) var service: Service?
    private(set) var appointment: Appointment?
    private(set) var fields: [TreatmentFormField] = []
    /// The form's fields plus the recommendation, which only the voice path proposes.
    private(set) var reviewFields: [TreatmentFormField] = []
    var draft = TreatmentDraft()
    var locale = Locale.current

    // Voice path.
    var voiceAvailability: VoiceAvailability?
    var structuringAvailable = false
    var transcript = ""
    var isListening = false
    var elapsed: TimeInterval = 0
    var heardNothing = false
    var proposals: [ReviewProposal] = []
    var rejectedCount = 0
    var usedTranscript = false

    // Saving.
    var isSaving = false
    var failure: Failure?
    var showsValidation = false
    var savedRecord: TreatmentRecord?

    // After saving.
    var photos: [FlowPhoto] = []
    private(set) var hasPhotoConsent = false
    private(set) var photoConsentDate: Date?
    var isProcessingPhoto = false
    var nextWeeks = NextSessionRules.fallbackWeeks
    var suggestionSaved = false
    /// The names in her product list, offered while she fills in the products used.
    private(set) var productNames: [String] = []

    let repository: (any ClientRecordRepository)?
    let profile: ProfileService
    let voice: any VoiceCapturing
    let structuring: any RecordStructuring
    let photoProcessing: any PhotoProcessing
    let now: @Sendable () -> Date
    let makeID: @Sendable () -> UUID
    let fallbackServiceName: String
    let notesName: String
    let recommendationName: String
    let recordID: UUID
    var listenTask: Task<Void, Never>?
    var tickTask: Task<Void, Never>?
    var organizeTask: Task<Void, Never>?
    var startedAt: Date?

    init(
        request: TreatmentFlowRequest,
        repository: (any ClientRecordRepository)?,
        profile: ProfileService,
        voice: any VoiceCapturing = UnavailableVoiceCapture(),
        structuring: any RecordStructuring = UnavailableRecordStructuring(),
        photoProcessing: any PhotoProcessing = ImageIOPhotoProcessing(),
        fallbackServiceName: String,
        notesName: String,
        recommendationName: String,
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.request = request
        self.repository = repository
        self.profile = profile
        self.voice = voice
        self.structuring = structuring
        self.photoProcessing = photoProcessing
        self.fallbackServiceName = fallbackServiceName
        self.notesName = notesName
        self.recommendationName = recommendationName
        self.now = now
        self.makeID = makeID
        self.recordID = makeID()
    }

    // MARK: - Derived

    var clientID: UUID { request.clientID }

    var serviceName: String {
        let name = service?.name ?? appointment?.serviceName ?? ""
        return name.isEmpty ? fallbackServiceName : name
    }

    /// The day the visit happened (or is happening): the appointment's start, today otherwise.
    var visitDate: Date { appointment?.startsAt ?? now() }

    /// Dates and numbers in her language, in the business time zone.
    var formatters: Formatters {
        let zone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: zone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }

    /// "Brazilian Glow · Sep 30, 15:00".
    var visitSubtitle: String {
        "\(BidiIsolate.wrap(serviceName)) · \(formatters.dateTime(visitDate))"
    }

    /// Anything she would lose by closing: typed answers, a transcript, an unfinished review. False once saved.
    var hasUnsavedWork: Bool {
        guard savedRecord == nil else { return false }
        return !draft.isEmpty || VoiceFlowRules.hasContent(transcript) || !proposals.isEmpty
    }

    var issues: [TreatmentRecordBuilder.Issue] {
        TreatmentRecordBuilder.issues(of: draft, fields: fields, locale: locale)
    }

    func issue(forNumberField key: String) -> Bool {
        issues.contains(.invalidNumber(key: key))
    }

    var canSaveForm: Bool { !isSaving && issues.isEmpty }

    // MARK: - Loading

    /// Reads the client, the service, the visit, the photo consent and her template, then builds the form. Safe to
    /// call again after a failure.
    func load() async {
        guard loadState != .ready else { return }
        guard let repository else {
            loadState = .failed
            return
        }
        do {
            guard let loaded = try await repository.client(id: request.clientID) else {
                loadState = .clientMissing
                return
            }
            client = loaded
            if let appointmentID = request.appointmentID {
                appointment = try await repository.appointment(id: appointmentID)
            }
            let serviceID = request.serviceID ?? appointment?.serviceID
            if let serviceID { service = try await repository.services().first { $0.id == serviceID } }
            let consent = PhotoConsentRules.latestPhotoConsent(try await repository.consents(for: loaded.id))
            productNames = ((try? await repository.products()) ?? []).map(\.name)
            hasPhotoConsent = consent != nil
            photoConsentDate = consent?.signedAt
            if profile.template == nil { await profile.load() }
            buildFields()
            nextWeeks = NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: service?.followUpWeeks)
            await refreshVoiceAvailability()
            loadState = .ready
        } catch {
            loadState = .failed
        }
    }

    /// She changed the interface language while the flow is open: the field names follow; what she typed stays.
    func useLocale(_ new: Locale) {
        locale = new
        if loadState == .ready { buildFields() }
    }

    func reload() {
        loadState = .loading
        Task { await load() }
    }

    private func buildFields() {
        // Field names are interface text (she reads them), so they come in the interface language.
        let localization = AppLocalization(resolving: locale)
        let catalog = (try? ProfessionCatalog.loadBundled(localization: localization))
            ?? ProfessionCatalog(localization: localization.rawValue, status: "needs_review", entries: [])
        fields = TreatmentFormFields.resolve(
            template: profile.template, professions: profile.profile?.professions ?? [], catalog: catalog,
            notesName: notesName
        )
        reviewFields = TreatmentFormFields.withRecommendation(fields, name: recommendationName)
        prefillAftercare()
    }

    /// The service's own aftercare text starts the aftercare field, ready to edit: a convenience she can clear.
    private func prefillAftercare() {
        guard let template = service?.aftercareTemplate,
              !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let field = fields.first(where: { $0.role == .aftercare }), draft.value(for: field.key).isEmpty
        else { return }
        draft.set(template, for: field.key)
    }

    // MARK: - Navigation

    /// Replaces the screen on top of the stack, so Back never returns to a step that is over (listening, organizing).
    func replaceTop(with step: TreatmentFlowStep) {
        if !path.isEmpty { path.removeLast() }
        path.append(step)
    }

    /// Opens the form with what she said, if she said something, as notes she can edit.
    func writeItMyself() {
        applyTranscriptAsNotes()
        path.append(.form)
    }

    /// Her dictated words become the notes field, once, so nothing she said is lost when the technology cannot
    /// organize it (or when she would rather not wait). The record then says it came from voice.
    func applyTranscriptAsNotes() {
        guard VoiceFlowRules.hasContent(transcript) else { return }
        let existing = draft.value(for: TreatmentFormField.notesKey)
        guard !existing.contains(transcript) else { return }
        draft.set(existing.isEmpty ? transcript : existing + "\n" + transcript, for: TreatmentFormField.notesKey)
        usedTranscript = true
    }

    // MARK: - Saving

    /// Saves what she typed in the manual form (or the form that started from her dictated words).
    func saveForm() async {
        showsValidation = true
        guard canSaveForm else { return }
        await save(draft: draft, aiAssisted: false)
    }

    func saveFormTapped() { Task { await saveForm() } }

    /// Writes the record through the vault and moves to "Saved". The id is fixed at the start of the flow, so a retry
    /// after a failure updates the same record instead of adding a second one.
    func save(draft: TreatmentDraft, aiAssisted: Bool) async {
        guard !isSaving, let repository, let client else { return }
        isSaving = true
        failure = nil
        defer { isSaving = false }
        let context = TreatmentRecordBuilder.Context(
            clientID: client.id, appointmentID: request.appointmentID ?? appointment?.id,
            serviceID: service?.id ?? request.serviceID, serviceName: serviceName, id: recordID,
            createdAt: savedRecord?.createdAt ?? now(), source: usedTranscript ? .voice : .manual,
            aiAssisted: aiAssisted
        )
        let record = TreatmentRecordBuilder.build(draft: draft, fields: reviewFields, context: context, locale: locale)
        do {
            try await repository.save(record)
            savedRecord = record
            path = [.saved]
        } catch {
            failure = .save
        }
    }

    // MARK: - Closing

    /// Stops everything that is running. Called when the flow closes.
    func tearDown() {
        listenTask?.cancel()
        tickTask?.cancel()
        organizeTask?.cancel()
        if isListening {
            isListening = false
            Task { _ = await voice.stop() }
        }
    }
}
