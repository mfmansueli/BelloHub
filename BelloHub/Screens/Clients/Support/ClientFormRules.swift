//
//  ClientFormRules.swift
//  BelloHub
//

import Foundation

/// The rules of the new-client and edit-client forms with no UI: what is wrong with a draft, how a draft becomes a
/// `Client`, and whether a draft changed. One owner (CLAUDE.md section 2): the screens and the ViewModel only ask here.
///
/// A name is required. The phone is optional, but a phone she typed has to be a real number: it is normalized to
/// international form with the **business region** as the default country (a number with `+` or `00` keeps its own),
/// and the problem is shown next to the field. An email is optional and only checked lightly: the app never mails
/// anyone, so a strict check would only turn a harmless typo into a blocked save.
struct ClientFormRules: Sendable {
    enum Issue: Hashable, Sendable {
        case nameMissing
        case phone(PhoneNormalizer.Failure)
        case emailInvalid
        case birthday(BirthdayInput.Problem)
    }

    let catalog: RegionCatalog
    /// The professional's business region: the country a national number is read in.
    let region: RegionPreset

    /// `regionCode` is the business region (`ProfessionalProfile.regionCode`). Without a known one only numbers that
    /// carry their own country code are accepted: guessing a country would save a number nobody can call.
    init(catalog: RegionCatalog, regionCode: String?) {
        self.catalog = catalog
        region = catalog.preset(for: regionCode) ?? Self.noRegion
    }

    /// A region in which no national number is plausible, so only international numbers pass.
    private static let noRegion = RegionPreset(
        code: "ZZ", defaultCurrency: "USD", callingCode: "", trunkPrefix: nil, phonePatterns: [:], nationalLengths: [],
        defaultLocalization: "en", localizations: ["en"], messagingChannel: .whatsapp, privacyFrameworkId: "",
        healthDataResidency: .none, wave: 4, timeZones: []
    )

    private var normalizer: PhoneNormalizer { PhoneNormalizer(catalog: catalog) }

    // MARK: - Validation

    /// Everything wrong with `draft`, in the order of the fields. `original` is the client being edited: her stored
    /// number is accepted as it is while its text is not touched.
    func issues(in draft: ClientFormDraft, original: Client? = nil, now: Date, calendar: Calendar) -> [Issue] {
        let draft = draft.trimmed
        var found: [Issue] = []
        if draft.name.isEmpty { found.append(.nameMissing) }
        if let failure = phoneFailure(draft.phone, original: original) { found.append(.phone(failure)) }
        if !draft.email.isEmpty, !Self.isPlausibleEmail(draft.email) { found.append(.emailInvalid) }
        if case .failure(let problem) = draft.birthday.resolve(currentYear: calendar.component(.year, from: now)) {
            found.append(.birthday(problem))
        }
        return found
    }

    func phoneIssue(in draft: ClientFormDraft, original: Client? = nil) -> PhoneNormalizer.Failure? {
        phoneFailure(draft.phone.trimmingCharacters(in: .whitespacesAndNewlines), original: original)
    }

    /// A light check: one `@`, something before it, and a dot inside the domain with letters on both sides.
    static func isPlausibleEmail(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace) else { return false }
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = parts[1]
        guard let dot = domain.lastIndex(of: "."), dot != domain.startIndex,
              domain.index(after: dot) != domain.endIndex else { return false }
        return true
    }

    // MARK: - Draft to client

    /// A new client from `draft`, or nil while there are issues. She is `manual` (typed in by the professional).
    func newClient(
        from draft: ClientFormDraft, id: UUID, now: Date, calendar: Calendar, source: ClientSource = .manual
    ) -> Client? {
        guard issues(in: draft, now: now, calendar: calendar).isEmpty else { return nil }
        let draft = draft.trimmed
        guard case .success(let phone) = resolvedPhone(draft.phone, original: nil),
              case .success(let birthday) = draft.birthday.resolve(currentYear: calendar.component(.year, from: now))
        else { return nil }
        return Client(
            id: id, name: draft.name, phoneE164: phone, email: draft.email.isEmpty ? nil : draft.email,
            tagIDs: draft.tagIDs, source: source, birthday: birthday, createdAt: now,
            importantNote: draft.importantNote.isEmpty ? nil : draft.importantNote
        )
    }

    /// `client` with the fields the edit form shows replaced by `draft`, or nil while there are issues. Everything the
    /// form does not show (her private notes, her lists, her source, her archive state) is left exactly as it was.
    func updated(_ client: Client, from draft: ClientFormDraft, now: Date, calendar: Calendar) -> Client? {
        guard issues(in: draft, original: client, now: now, calendar: calendar).isEmpty else { return nil }
        let draft = draft.trimmed
        guard case .success(let phone) = resolvedPhone(draft.phone, original: client),
              case .success(let birthday) = draft.birthday.resolve(currentYear: calendar.component(.year, from: now))
        else { return nil }
        var result = client
        result.name = draft.name
        result.phoneE164 = phone
        result.email = draft.email.isEmpty ? nil : draft.email
        result.tagIDs = draft.tagIDs
        result.birthday = birthday
        result.onlineBookingStopped = draft.onlineBookingStopped
        result.stopReason = draft.onlineBookingStopped && !draft.stopReason.isEmpty ? draft.stopReason : nil
        result.remindersEnabled = draft.remindersEnabled
        return result
    }

    /// The draft the edit form starts from.
    func draft(for client: Client) -> ClientFormDraft {
        ClientFormDraft(
            name: client.name, phone: client.phoneE164.map(displayPhone) ?? "", email: client.email ?? "",
            tagIDs: client.tagIDs, importantNote: client.importantNote ?? "", birthday: BirthdayInput(client.birthday),
            onlineBookingStopped: client.onlineBookingStopped, stopReason: client.stopReason ?? "",
            remindersEnabled: client.remindersEnabled
        )
    }

    // MARK: - Tags

    /// The color tokens a tag can have (`Tag.colorToken`), in the order a new tag takes them.
    static let tagColorTokens = ["rose", "sage", "peach", "sand"]

    /// A tag made on the spot takes the next color in turn, so the chips on a client do not all look the same.
    static func tagColorToken(forPosition position: Int) -> String {
        tagColorTokens[max(position, 0) % tagColorTokens.count]
    }

    // MARK: - Changes

    /// Whether `draft` differs from where the form started: what unsaved changes are, for the "discard?" question.
    /// Spaces around a text and the order of the tags do not count; a stop reason only counts while booking is stopped.
    static func isDirty(_ draft: ClientFormDraft, comparedTo initial: ClientFormDraft) -> Bool {
        normalized(draft) != normalized(initial)
    }

    private static func normalized(_ draft: ClientFormDraft) -> ClientFormDraft {
        var result = draft.trimmed
        result.tagIDs = result.tagIDs.sorted { $0.uuidString < $1.uuidString }
        if !result.onlineBookingStopped { result.stopReason = "" }
        return result
    }

    // MARK: - Phone

    /// The number as the field shows it: international form with the country's own grouping.
    func displayPhone(_ e164: String) -> String {
        PhoneFormatter(catalog: catalog).international(e164)
    }

    private func resolvedPhone(_ input: String, original: Client?) -> Result<String?, PhoneNormalizer.Failure> {
        if input.isEmpty { return .success(nil) }
        // Untouched text keeps the stored number: re-validating it could block an edit of something else.
        if let stored = original?.phoneE164, input == displayPhone(stored) { return .success(stored) }
        return normalizer.normalize(input, defaultRegion: region).map { Optional($0) }
    }

    private func phoneFailure(_ input: String, original: Client?) -> PhoneNormalizer.Failure? {
        if case .failure(let failure) = resolvedPhone(input, original: original) { return failure }
        return nil
    }
}
