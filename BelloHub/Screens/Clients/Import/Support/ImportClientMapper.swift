//
//  ImportClientMapper.swift
//  BelloHub
//

import Foundation

/// Applies the rules of the import to what a source found: the name is cleaned and must be a person's name, the phone
/// is normalized to E.164 with the business region (and may be missing, but never wrong), the e-mail passes a light
/// check. A candidate that passes becomes a `Client` with a new id and the source `.importedClients`; one that does not
/// becomes a malformed entry with the reason. One owner for these rules: the contacts and the spreadsheet both come
/// through here, so they can never disagree.
struct ImportClientMapper: Sendable {
    let region: RegionPreset
    let phones: PhoneNormalizer
    /// The moment the clients are created, passed in so the rule is testable.
    let now: Date

    /// The entries of a batch, in the order given. `makeID` supplies the new client ids (tests pass a counter).
    func entries(from candidates: [ImportCandidate], makeID: () -> UUID = { UUID() }) -> [ImportEntry] {
        candidates.map { entry(for: $0, id: makeID()) }
    }

    func entry(for candidate: ImportCandidate, id: UUID) -> ImportEntry {
        let name = OnboardingRules.cleaned(candidate.name)
        func malformed(_ issue: ImportRowIssue) -> ImportEntry {
            ImportEntry(id: candidate.id, displayName: name, rowNumber: candidate.rowNumber, outcome: .malformed(issue))
        }

        if name.isEmpty { return malformed(.nameMissing) }
        if !OnboardingRules.isValidPersonName(name) { return malformed(.nameLength) }

        let phone: String?
        switch ImportPhoneRules.pick(from: candidate.phoneNumbers, normalizer: phones, region: region) {
        case .none: phone = nil
        case .valid(let e164): phone = e164
        case .invalid: return malformed(.invalidPhone)
        }

        let email: String?
        switch ImportEmailRules.check(candidate.email) {
        case .none: email = nil
        case .valid(let address): email = address
        case .invalid: return malformed(.invalidEmail)
        }

        let client = Client(
            id: id, name: name, phoneE164: phone, email: email, source: .importedClients,
            birthday: candidate.birthday, createdAt: now
        )
        return ImportEntry(id: candidate.id, displayName: name, rowNumber: candidate.rowNumber, outcome: .ready(client))
    }

    /// The same entries sorted by name the way the system sorts (accents and case ignored, "Ana 2" before "Ana 10"):
    /// contacts arrive in the order she tapped them, and a list she scans wants an order. A spreadsheet keeps the order
    /// of its file instead, because that is the order she knows.
    static func sortedByName(_ entries: [ImportEntry]) -> [ImportEntry] {
        entries.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}
