//
//  ClientFormViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the new-client sheet (4.2) and the edit-client screen (4.3), which are one form with two
/// modes. A client is only ever saved through the registration gate (`ClientRegistering.register`, D42): a new one is
/// counted, an edit never is. The rules (validation, normalization, what counts as unsaved) are `ClientFormRules`.
@MainActor
@Observable
final class ClientFormViewModel {
    enum Mode: Equatable, Sendable {
        case new
        case edit(clientID: UUID)
    }

    /// How the form ended, so the screen that presented it knows where to go next.
    enum Finish: Equatable, Sendable {
        /// A new client was saved and counted: open her profile.
        case registered(UUID)
        case updated(UUID)
        case archived(UUID)
        case restored(UUID)
    }

    let mode: Mode
    /// What the fields edit.
    var draft = ClientFormDraft()
    private(set) var original: Client?
    private(set) var isLoading: Bool
    /// The client being edited is gone (merged away or deleted while the screen was open).
    private(set) var isMissing = false
    /// Turns on after the first tap on Save, so a field she has not reached yet is not scolded.
    private(set) var showsValidation = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var finish: Finish?
    /// Another client has this number: nothing was saved, and the form offers to open her.
    private(set) var duplicateClientID: UUID?
    /// The free registrations are used: the paywall sheet is up.
    var showsPaywall = false

    private let registrar: any ClientRegistering
    private let vault: VaultService
    private let profile: ProfileService
    private let rules: ClientFormRules
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID
    private let newClientID: UUID
    private var initial = ClientFormDraft()
    private var duplicatePhone = ""

    init(
        mode: Mode,
        registrar: any ClientRegistering,
        vault: VaultService,
        profile: ProfileService,
        regions: RegionCatalog = RegionCatalog(presets: []),
        now: @escaping @Sendable () -> Date = { Date() },
        makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.mode = mode
        self.registrar = registrar
        self.vault = vault
        self.profile = profile
        self.rules = ClientFormRules(catalog: regions, regionCode: profile.profile?.regionCode)
        self.now = now
        self.makeID = makeID
        self.newClientID = makeID()
        self.isLoading = mode != .new
    }

    // MARK: - Derived

    var isNew: Bool { mode == .new }

    /// The registration counter for the limit note.
    var usage: RegistrationUsage { registrar.usage }

    var tags: [Tag] { profile.tags.sorted { ($0.position, $0.name) < ($1.position, $1.name) } }

    var isDirty: Bool { ClientFormRules.isDirty(draft, comparedTo: initial) }

    /// New clients can always be saved (the form says what is missing); an edit only once something changed.
    var canSave: Bool { !isSaving && !isLoading && (isNew || isDirty) }

    var issues: [ClientFormRules.Issue] {
        rules.issues(in: draft, original: original, now: now(), calendar: calendar)
    }

    /// What to say next to each field. Empty until she first tries to save.
    var nameIssue: ClientFormRules.Issue? { shown.first { $0 == .nameMissing } }
    var phoneMissing: Bool { shown.contains(.phoneMissing) }
    var phoneFailure: PhoneNormalizer.Failure? {
        shown.lazy.compactMap { if case .phone(let failure) = $0 { failure } else { nil } }.first
    }
    var phoneMismatch: Bool { shown.contains(.phoneMismatch) }
    var emailMissing: Bool { shown.contains(.emailMissing) }
    var emailIssue: ClientFormRules.Issue? { shown.first { $0 == .emailInvalid } }
    var emailMismatch: Bool { shown.contains(.emailMismatch) }
    var birthdayProblem: BirthdayInput.Problem? {
        shown.lazy.compactMap { if case .birthday(let problem) = $0 { problem } else { nil } }.first
    }

    /// The "this number already belongs to someone" notice, while the number is still the one that was refused.
    var duplicateNotice: UUID? {
        guard let duplicateClientID,
              draft.phone.trimmingCharacters(in: .whitespacesAndNewlines) == duplicatePhone else { return nil }
        return duplicateClientID
    }

    /// This year in the Gregorian calendar of the business time zone, for the birthday's year menu: the device's own
    /// calendar may count another era (the Islamic year is 1448).
    var currentYear: Int { calendar.component(.year, from: now()) }

    /// Her name for the labels that mention her ("Stop online booking for Ana"): the first word of the name.
    var firstName: String {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    // MARK: - Loading

    /// Edit mode: reads the client and starts the draft from her. Nothing to do for a new client.
    func load() async {
        guard case .edit(let clientID) = mode else { return }
        guard let repository = vault.repository else { return fail() }
        do {
            guard let client = try await repository.client(id: clientID) else {
                isMissing = true
                isLoading = false
                return
            }
            original = client
            initial = rules.draft(for: client)
            draft = initial
            isLoading = false
        } catch {
            fail()
        }
    }

    /// The counter of the limit note, read from the ledger.
    func refreshUsage() async {
        await registrar.refreshUsage()
    }

    // MARK: - Tags

    func toggleTag(_ id: UUID) {
        if let index = draft.tagIDs.firstIndex(of: id) {
            draft.tagIDs.remove(at: index)
        } else {
            draft.tagIDs.append(id)
        }
    }

    /// "+ New tag": saves the tag in the business setup and selects it for this client. A name she already has selects
    /// the existing tag instead of making a twin.
    func addTag(named name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = ClientMerger.comparisonKey(trimmed)
        if let existing = profile.tags.first(where: { ClientMerger.comparisonKey($0.name) == key }) {
            if !draft.tagIDs.contains(existing.id) { draft.tagIDs.append(existing.id) }
            return
        }
        guard let repository = vault.repository else { return fail() }
        let position = (profile.tags.map(\.position).max() ?? -1) + 1
        let tag = Tag(
            id: makeID(), name: trimmed, colorToken: ClientFormRules.tagColorToken(forPosition: position),
            position: position
        )
        do {
            try await repository.save(tag)
            await profile.load()
            guard profile.tags.contains(where: { $0.id == tag.id }) else { return fail() }
            draft.tagIDs.append(tag.id)
        } catch {
            fail()
        }
    }

    // MARK: - Saving

    /// Fire-and-forget entry point for the Save button (CLAUDE.md section 2).
    func save() {
        Task { await saveAsync() }
    }

    func saveAsync() async {
        await persist(archiving: nil)
    }

    /// Archives the client (or brings her back) together with whatever is in the form.
    func setArchived(_ archived: Bool) {
        Task { await persist(archiving: archived) }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    private var shown: [ClientFormRules.Issue] { showsValidation ? issues : [] }

    private func persist(archiving archived: Bool?) async {
        guard !isSaving else { return }
        showsValidation = true
        guard let client = clientToSave(archiving: archived) else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            // The gate reads a client with her own id as an edit, so it never notices that she was given another
            // client's number: that clash is caught here, before anything is saved.
            if !isNew, let owner = try await otherOwner(ofPhoneIn: client) {
                duplicateClientID = owner
                duplicatePhone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
                return
            }
            switch try await registrar.register(client) {
            case .registered:
                finish = .registered(client.id)
            case .updated:
                finish = finishAfterUpdate(of: client, archiving: archived)
            case .duplicate(let existingID):
                duplicateClientID = existingID
                duplicatePhone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
            case .needsSubscription:
                showsPaywall = true
            }
        } catch {
            errorMessage = String(interface: LocalizedStringResource("clientForm.error.save"))
        }
    }

    /// The other client who already has this client's number, by `ClientDuplicateRules`.
    private func otherOwner(ofPhoneIn client: Client) async throws -> UUID? {
        guard let repository = vault.repository else { return nil }
        let others = try await repository.allClients().filter { $0.id != client.id }
        return ClientDuplicateRules.existing(matching: client, in: others)?.id
    }

    private func clientToSave(archiving archived: Bool?) -> Client? {
        let calendar = calendar
        switch mode {
        case .new:
            return rules.newClient(from: draft, id: newClientID, now: now(), calendar: calendar)
        case .edit:
            guard let original, var client = rules.updated(original, from: draft, now: now(), calendar: calendar)
            else { return nil }
            if let archived { client.isArchived = archived }
            return client
        }
    }

    private func finishAfterUpdate(of client: Client, archiving archived: Bool?) -> Finish {
        switch archived {
        case true?: .archived(client.id)
        case false?: .restored(client.id)
        case nil: .updated(client.id)
        }
    }

    private func fail() {
        isLoading = false
        errorMessage = String(interface: LocalizedStringResource("clientForm.error.load"))
    }

    /// The business time zone decides which year is "this year" for a birthday (docs/07 section 2.4).
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profile.profile.flatMap { TimeZone(identifier: $0.timeZoneID) } ?? .current
        return calendar
    }
}
