//
//  CredentialRules.swift
//  BelloHub
//

import Foundation

/// The rules of the credentials screen that have no UI: which entries are accepted, how a draft becomes a `Credential`,
/// how the registration number is kept as one special entry, and how the "show on my booking page" switch applies to
/// all of them. One owner for each rule (CLAUDE.md section 2).
enum CredentialRules {
    static let maximumTitleLength = 80
    static let maximumInstitutionLength = 80
    static let maximumRegistrationLength = 40
    static let earliestYear = 1950

    // MARK: - Reading the list

    /// The courses and certificates, in her order.
    static func trainings(_ all: [Credential]) -> [Credential] {
        all.filter { $0.kind == .training }.sorted { ($0.position, $0.title) < ($1.position, $1.title) }
    }

    /// Her registration, when she entered one.
    static func registration(_ all: [Credential]) -> Credential? {
        all.first { $0.kind == .registration }
    }

    /// Whether the page shows her credentials. All of them move together, so any one that is on means the switch is on;
    /// with nothing to read it from, `fallback` (the switch as she last left it) decides.
    static func showsOnPage(_ all: [Credential], fallback: Bool) -> Bool {
        all.isEmpty ? fallback : all.contains { $0.showOnBookingPage }
    }

    /// The credentials whose visibility has to change for the switch to read `show`: the ones that differ.
    static func setting(_ all: [Credential], show: Bool) -> [Credential] {
        all.filter { $0.showOnBookingPage != show }.map { credential in
            var changed = credential
            changed.showOnBookingPage = show
            return changed
        }
    }

    // MARK: - The form

    /// The year she typed, read in any digits her language uses. Nil for an empty field.
    static func year(from text: String) -> Int? {
        let digits = DigitNormalizer.ascii(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return digits.isEmpty ? nil : Int(digits)
    }

    /// Everything wrong with the draft, in the order the form shows it. Empty means it can be saved. `currentYear` is
    /// the year in her time zone (next year is allowed: a course that starts soon).
    static func issues(in draft: CredentialDraft, currentYear: Int) -> [CredentialFormIssue] {
        var found: [CredentialFormIssue] = []
        let title = OnboardingRules.cleaned(draft.title)
        if title.isEmpty { found.append(.titleEmpty) }
        if title.count > maximumTitleLength { found.append(.titleTooLong) }
        if OnboardingRules.cleaned(draft.institution).count > maximumInstitutionLength {
            found.append(.institutionTooLong)
        }
        let typed = DigitNormalizer.ascii(draft.yearText).trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty {
            guard let value = Int(typed), (earliestYear...(currentYear + 1)).contains(value) else {
                return found + [.yearInvalid]
            }
        }
        return found
    }

    /// The credential the draft describes, or nil when it has an issue. `existing` keeps its id and place; a new one
    /// goes after the last and starts with the page switch as it stands.
    static func build(
        _ draft: CredentialDraft, among all: [Credential], editing existing: Credential? = nil, showOnPage: Bool,
        currentYear: Int, makeID: () -> UUID = UUID.init
    ) -> Credential? {
        guard issues(in: draft, currentYear: currentYear).isEmpty else { return nil }
        return Credential(
            id: existing?.id ?? makeID(), kind: .training, title: OnboardingRules.cleaned(draft.title),
            institution: OnboardingRules.cleaned(draft.institution), year: year(from: draft.yearText),
            registrationNumber: nil, showOnBookingPage: existing?.showOnBookingPage ?? showOnPage,
            position: existing?.position ?? PositionRules.next(after: all)
        )
    }

    /// "Senac SP · 2019", "2022", "Senac SP" or nothing, under a credential's title. The year is written in her digits.
    static func details(of credential: Credential, locale: Locale) -> String {
        let year = credential.year.map { $0.formatted(.number.locale(locale).grouping(.never)) }
        return [credential.institution, year].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // MARK: - The registration number

    /// The registration number as she wrote it, cleaned.
    static func cleanedRegistration(_ text: String) -> String {
        OnboardingRules.cleaned(text)
    }

    /// Whether `text` can be stored as the registration number.
    static func isValidRegistration(_ text: String) -> Bool {
        cleanedRegistration(text).count <= maximumRegistrationLength
    }

    /// What typing `text` in the registration field changes. The number lives on one credential of kind
    /// `.registration`; it is created on the first number, updated on a change and removed when the field is emptied.
    static func registrationChange(
        text: String, among all: [Credential], showOnPage: Bool, makeID: () -> UUID = UUID.init
    ) -> RegistrationChange {
        let number = cleanedRegistration(text)
        guard isValidRegistration(number) else { return .none }
        let existing = registration(all)
        if number.isEmpty { return existing.map { .remove(id: $0.id) } ?? .none }
        if existing?.registrationNumber == number { return .none }
        var credential = existing ?? Credential(
            id: makeID(), kind: .registration, title: "", showOnBookingPage: showOnPage,
            position: PositionRules.next(after: all)
        )
        credential.registrationNumber = number
        return .save(credential)
    }
}
