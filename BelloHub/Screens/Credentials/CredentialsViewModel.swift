//
//  CredentialsViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of the Training and credentials screen (6.10): her courses and certificates, her professional
/// registration number and the one switch that shows them on her booking page. Every change is written to the vault
/// first and shown after it confirms (CLAUDE.md section 2); a failed write leaves the screen as it was and says so.
@MainActor
@Observable
final class CredentialsViewModel {
    private(set) var credentials: [Credential] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    /// The list could not be read; the screen shows this with a retry.
    private(set) var errorMessage: String?
    /// A change could not be saved; the screen shows it above the list and the list stays as it was.
    private(set) var saveErrorMessage: String?
    /// The text of the registration field. The screen binds to it; `commitRegistration()` stores it.
    var registrationText = ""
    /// The switch as she last left it, used while there is no credential to read it from (she can switch it before she
    /// adds the first one; the next one she adds starts with it).
    private var showOnPageWhenEmpty = true

    private let repository: (any CatalogRepository)?
    private let locale: Locale
    private let timeZone: TimeZone
    private let now: @Sendable () -> Date
    private let makeID: @Sendable () -> UUID

    init(
        repository: (any CatalogRepository)?, locale: Locale = .current, timeZone: TimeZone = .current,
        now: @escaping @Sendable () -> Date = { Date() }, makeID: @escaping @Sendable () -> UUID = { UUID() }
    ) {
        self.repository = repository
        self.locale = locale
        self.timeZone = timeZone
        self.now = now
        self.makeID = makeID
    }

    // MARK: - Reading

    /// The courses and certificates, in her order.
    var trainings: [Credential] { CredentialRules.trainings(credentials) }

    var registration: Credential? { CredentialRules.registration(credentials) }

    /// Whether her credentials show on her booking page.
    var showsOnPage: Bool { CredentialRules.showsOnPage(credentials, fallback: showOnPageWhenEmpty) }

    /// Whether she has no course or certificate yet and nothing is wrong: the list says so and offers the first one. It
    /// is a line inside the list, not a screen of its own, because the page switch and the registration are still hers
    /// to set.
    var showsEmptyState: Bool { hasLoaded && errorMessage == nil && trainings.isEmpty }

    /// Whether to draw placeholder rows: the first read is running and there is nothing to show yet.
    var showsSkeleton: Bool { isLoading && !hasLoaded && credentials.isEmpty }

    func draft(for credential: Credential?) -> CredentialDraft {
        credential.map { CredentialDraft($0, locale: locale) } ?? CredentialDraft()
    }

    func issues(in draft: CredentialDraft) -> [CredentialFormIssue] {
        CredentialRules.issues(in: draft, currentYear: currentYear)
    }

    /// Whether the registration field holds something that can be stored.
    var isRegistrationValid: Bool { CredentialRules.isValidRegistration(registrationText) }

    func details(of credential: Credential) -> String {
        CredentialRules.details(of: credential, locale: locale)
    }

    /// The year in her time zone, on the Gregorian calendar: `Calendar.current` is the Islamic calendar under some
    /// Arabic regions, and a 1448 would be refused as a year of training.
    private var currentYear: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.component(.year, from: now())
    }

    // MARK: - Loading

    /// Entry point for appearing and retrying; `loadAsync()` is what `.refreshable` awaits.
    func load() {
        Task { await loadAsync() }
    }

    func loadAsync() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }
        guard let repository else {
            errorMessage = Self.loadFailure
            return
        }
        do {
            credentials = try await repository.credentials()
            registrationText = registration?.registrationNumber ?? ""
        } catch {
            errorMessage = Self.loadFailure
        }
    }

    func dismissSaveError() {
        saveErrorMessage = nil
    }

    // MARK: - Editing

    /// Adds a credential, or applies the draft to the one being edited. Returns whether it was saved; a draft with an
    /// issue returns false without touching anything (the form shows why while she types).
    @discardableResult
    func save(_ draft: CredentialDraft, editing credential: Credential?) async -> Bool {
        guard let repository, let built = CredentialRules.build(
            draft, among: credentials, editing: credential, showOnPage: showsOnPage, currentYear: currentYear,
            makeID: makeID
        ) else { return false }
        saveErrorMessage = nil
        do {
            try await repository.save(built)
            credentials = credentials.filter { $0.id != built.id } + [built]
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Deletes a credential. Returns whether it was deleted.
    @discardableResult
    func delete(_ credential: Credential) async -> Bool {
        guard let repository else { return false }
        saveErrorMessage = nil
        do {
            try await repository.deleteCredential(id: credential.id)
            credentials.removeAll { $0.id == credential.id }
            return true
        } catch {
            saveErrorMessage = Self.saveFailure
            return false
        }
    }

    /// Entry point for the switch; `setShowsOnPageAsync` is what tests await.
    func setShowsOnPage(_ show: Bool) {
        Task { await setShowsOnPageAsync(show) }
    }

    /// Shows or hides all her credentials on the booking page, in one write.
    func setShowsOnPageAsync(_ show: Bool) async {
        guard let repository else { return }
        let changed = CredentialRules.setting(credentials, show: show)
        saveErrorMessage = nil
        guard !changed.isEmpty else {
            showOnPageWhenEmpty = show
            return
        }
        do {
            try await repository.save(changed)
            let changedByID = Dictionary(uniqueKeysWithValues: changed.map { ($0.id, $0) })
            credentials = credentials.map { changedByID[$0.id] ?? $0 }
            showOnPageWhenEmpty = show
        } catch {
            saveErrorMessage = Self.saveFailure
        }
    }

    /// Entry point for the field losing focus, its return key and the screen going away.
    func commitRegistration() {
        Task { await commitRegistrationAsync() }
    }

    /// Stores what is in the registration field: a new registration, a changed one, or none when it was emptied.
    func commitRegistrationAsync() async {
        guard let repository, hasLoaded else { return }
        let change = CredentialRules.registrationChange(
            text: registrationText, among: credentials, showOnPage: showsOnPage, makeID: makeID
        )
        saveErrorMessage = nil
        do {
            switch change {
            case .none:
                break
            case .save(let credential):
                try await repository.save(credential)
                credentials = credentials.filter { $0.id != credential.id } + [credential]
            case .remove(let id):
                try await repository.deleteCredential(id: id)
                credentials.removeAll { $0.id == id }
            }
        } catch {
            saveErrorMessage = Self.saveFailure
        }
    }

    // MARK: - Messages

    private static var loadFailure: String {
        String(
            localized: "credentials.error.load",
            defaultValue: "We could not read your credentials. Check that your iPhone is unlocked and try again."
        )
    }

    private static var saveFailure: String {
        String(
            localized: "credentials.error.save",
            defaultValue: "We could not save this change. Check that your iPhone has space and try again."
        )
    }
}
