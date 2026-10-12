//
//  TreatmentFlowViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// The state of the whole visit flow: who the visit is for, the questions of her template, what she has answered,
/// the photos, the visit day, the draft's automatic save, the transcript and proposals of the voice path, and the
/// finalized record. The draft, voice, review, photo and next-session parts are in extensions of this class (one file
/// each); the rules they apply are pure types in `Support/`. Nothing here reaches the network: the vault is the only
/// store.
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
        case delete
    }

    let request: TreatmentFlowRequest
    var path: [TreatmentFlowStep] = []
    var loadState = LoadState.loading
    var client: Client?
    var service: Service?
    var appointment: Appointment?
    /// Her services, for a visit with no appointment: she picks what was done.
    var services: [Service] = []
    var fields: [TreatmentFormField] = []
    /// The form's fields plus the recommendation, which only the voice path proposes.
    var reviewFields: [TreatmentFormField] = []
    var draft = TreatmentDraft()
    var locale = Locale.current
    /// The day and time the treatment happened; the appointment's start or now, and she can change it.
    var performedAt = Date()

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
    var aiAssisted = false

    // Saving.
    var isSaving = false
    var failure: Failure?
    var showsValidation = false
    /// The record as stored now: the draft while she works, the finalized record after.
    var savedRecord: TreatmentRecord?
    var autosave = AutosaveState.idle
    var autosaveTask: Task<Void, Never>?

    // Photos and next visit.
    var photos: [FlowPhoto] = []
    var hasPhotoConsent = false
    var photoConsentDate: Date?
    var isProcessingPhoto = false
    var nextWeeks = NextSessionRules.fallbackWeeks
    /// The names in her product list, offered while she fills in the products used.
    var productNames: [String] = []
    /// How far the closing of an older visit went (routine-a item 7); only resumed, never started any more.
    var closing: VisitClosing?
    /// Her latest record of this client and service, for "Same as last visit" (routine-a item 8).
    var lastVisit: TreatmentRecord?
    /// The parts copied from a past visit she used as the base, kept until the first save carries them.
    var carriedFromBase: TreatmentRecord?
    /// What the flow wrote in the form by itself, by field key. A form holding only these is still empty: nothing is
    /// stored until she changes something.
    var startingValues: [String: String] = [:]

    let repository: (any ClientRecordRepository)?
    let profile: ProfileService
    let voice: any VoiceCapturing
    let structuring: any RecordStructuring
    let photoProcessing: any PhotoProcessing
    /// Where the closing progress of older visits is kept (per user, on this iPhone); nil in tests that do not look.
    let closings: FollowUpQueueService?
    /// Her saved options (techniques), for "+ Add"; nil in tests that do not look.
    let options: OptionCatalogService?
    let now: @Sendable () -> Date
    let makeID: @Sendable () -> UUID
    let names: FieldNames
    /// How long the draft waits after a change before it is written, so typing is not a save per letter.
    let autosaveDelay: Duration
    /// Fixed when the flow opens, so every save (automatic or not) writes the same record and a retry never adds a
    /// second one. Replaced at load by the record already made for the appointment, if there is one.
    var recordID: UUID
    var listenTask: Task<Void, Never>?
    var tickTask: Task<Void, Never>?
    var organizeTask: Task<Void, Never>?
    var startedAt: Date?

    /// The names of the fields the flow adds itself, in her language.
    struct FieldNames: Equatable, Sendable {
        var serviceFallback: String
        var notes: String
        var recommendation: String
        var aftercare = "Aftercare"
        var reaction = "Reaction"
        var reminder = "Remember next time"
    }

    init(
        request: TreatmentFlowRequest,
        repository: (any ClientRecordRepository)?,
        profile: ProfileService,
        voice: any VoiceCapturing = UnavailableVoiceCapture(),
        structuring: any RecordStructuring = UnavailableRecordStructuring(),
        photoProcessing: any PhotoProcessing = ImageIOPhotoProcessing(),
        closings: FollowUpQueueService? = nil,
        options: OptionCatalogService? = nil,
        names: FieldNames,
        autosaveDelay: Duration = .milliseconds(800),
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.request = request
        self.repository = repository
        self.profile = profile
        self.voice = voice
        self.structuring = structuring
        self.photoProcessing = photoProcessing
        self.closings = closings
        self.options = options
        self.names = names
        self.autosaveDelay = autosaveDelay
        self.now = now
        self.makeID = makeID
        // A record she is continuing (or an older visit she is resuming) keeps its own id.
        self.recordID = request.recordID ?? request.resumeRecordID ?? makeID()
    }

    // MARK: - Derived

    var clientID: UUID { request.clientID }

    var serviceName: String {
        let name = service?.name ?? appointment?.serviceName ?? savedRecord?.serviceName ?? ""
        return name.isEmpty ? names.serviceFallback : name
    }

    /// The day the visit happened (or is happening), as set on the form.
    var visitDate: Date { performedAt }

    /// Dates and numbers in her language, in the business time zone.
    var formatters: Formatters {
        let zone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return Formatters(locale: locale, timeZone: zone, currencyCode: profile.profile?.currencyCode ?? "USD")
    }

    /// "Brazilian Glow · Sep 30, 15:00".
    var visitSubtitle: String {
        "\(BidiIsolate.wrap(serviceName)) · \(formatters.dateTime(visitDate))"
    }

    /// The record is finalized and its 24 hours are over: its fields read only, photos can still be added.
    var isLocked: Bool {
        guard let record = savedRecord, !record.isDraft else { return false }
        return RecordLockPolicy.isLocked(lockedAt: record.lockedAt, now: now())
    }

    var isFinalized: Bool { savedRecord.map { !$0.isDraft } ?? false }

    /// Something worth keeping: an answer or a result she gave, or a photo. An empty draft is never stored.
    var hasContent: Bool { draft.hasAnswers(besides: startingValues) || !photos.isEmpty }

    var issues: [TreatmentRecordBuilder.Issue] {
        var found = TreatmentRecordBuilder.issues(of: draft, fields: fields, locale: locale)
            .filter { $0 != .nothingToSave }
        // A visit documented only with photos is a complete record too, and so is a past visit repeated as it was.
        // Only the service's standard aftercare text is not.
        if !hasContent, carriedFromBase == nil { found.insert(.nothingToSave, at: 0) }
        return found
    }

    func issue(forNumberField key: String) -> Bool {
        issues.contains(.invalidNumber(key: key))
    }

    var canFinalize: Bool { !isSaving && issues.isEmpty && !isLocked }

    /// Where each field goes on the form.
    var sections: VisitFormSections { VisitFormSections.split(fields, draft: draft) }

    // MARK: - Loading

    /// Reads the client, the visit, her services, the photo consent and her template; then opens the record she is
    /// continuing (or the one already made for this appointment), or starts from a past visit she chose as the base.
    /// Safe to call again after a failure.
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
            services = try await repository.services().filter(\.isActive)
            let records = try await repository.records(for: loaded.id)
            let existing = existingRecord(in: records)
            let serviceID = existing?.serviceID ?? request.serviceID ?? appointment?.serviceID
            if let serviceID { service = try await repository.services().first { $0.id == serviceID } }
            let consent = PhotoConsentRules.latestPhotoConsent(try await repository.consents(for: loaded.id))
            hasPhotoConsent = consent != nil
            photoConsentDate = consent?.signedAt
            productNames = ((try? await repository.products()) ?? []).map(\.name)
            lastVisit = LastVisitPrefill.source(
                records: records.filter { !$0.isDraft }, serviceID: serviceID, serviceName: serviceName,
                excluding: recordID
            )
            if profile.template == nil { await profile.load() }
            await options?.loadIfNeeded()
            buildFields()
            // A visit opened before its appointment starts is still today, never a day to come.
            performedAt = min(appointment?.startsAt ?? now(), now())
            nextWeeks = NextSessionRules.suggestedWeeks(serviceFollowUpWeeks: service?.followUpWeeks)
            if let existing {
                await open(existing)
            } else if let base = request.base, let source = records.first(where: { $0.id == base.recordID }) {
                applyBase(source, parts: base.parts)
            }
            await refreshVoiceAvailability()
            loadState = .ready
            resumeClosingIfRequested()
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

    /// The record this flow continues: the one the request names, else the one already made for the appointment
    /// (`RecordForAppointment`), so opening "Register visit" twice for one appointment never makes two records.
    private func existingRecord(in records: [TreatmentRecord]) -> TreatmentRecord? {
        if let named = request.recordID ?? request.resumeRecordID {
            return records.first { $0.id == named }
        }
        guard let found = RecordForAppointment.existing(in: records, appointmentID: request.appointmentID) else {
            return nil
        }
        recordID = found.id
        return found
    }

    /// Rebuilds the fields after her template changed (a choice saved from the form); what she wrote stays.
    func buildFieldsKeepingAnswers() {
        let answers = draft
        buildFields()
        draft = answers
    }

    private func buildFields() {
        // Field names are interface text (she reads them), so they come in the interface language.
        let localization = AppLocalization(resolving: locale)
        let catalog = (try? ProfessionCatalog.loadBundled(localization: localization))
            ?? ProfessionCatalog(localization: localization.rawValue, status: "needs_review", entries: [])
        let template = TreatmentFormFields.resolve(
            template: profile.template, professions: profile.profile?.professions ?? [], catalog: catalog,
            notesName: names.notes
        )
        fields = TreatmentFormFields.withVisitFields(
            template, aftercareName: names.aftercare, reactionName: names.reaction, reminderName: names.reminder
        )
        reviewFields = TreatmentFormFields.withRecommendation(fields, name: names.recommendation)
        prefillAftercare()
    }

    /// The service's own aftercare text starts the aftercare field of a new visit, ready to edit: a convenience she
    /// can clear. A record she is continuing keeps what it says.
    func prefillAftercare() {
        guard savedRecord == nil, let template = service?.aftercareTemplate,
              !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let field = fields.first(where: { $0.role == .aftercare }), draft.value(for: field.key).isEmpty
        else { return }
        draft.set(template, for: field.key)
        startingValues[field.key] = draft.value(for: field.key)
    }

    // MARK: - Navigation

    /// Replaces the screen on top of the stack, so Back never returns to a step that is over (listening, organizing).
    func replaceTop(with step: TreatmentFlowStep) {
        if !path.isEmpty { path.removeLast() }
        path.append(step)
    }

    /// Back to the visit form, the root of the flow (after the voice path, or after reviewing proposals).
    func returnToForm() {
        path = []
    }

    /// Her dictated words become the notes field, once, so nothing she said is lost when the technology cannot
    /// organize it (or when she would rather not wait). The record then says it came from voice.
    func applyTranscriptAsNotes() {
        guard VoiceFlowRules.hasContent(transcript) else { return }
        let existing = draft.value(for: TreatmentFormField.notesKey)
        guard !existing.contains(transcript) else { return }
        draft.set(existing.isEmpty ? transcript : existing + "\n" + transcript, for: TreatmentFormField.notesKey)
        usedTranscript = true
        draftChanged()
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
