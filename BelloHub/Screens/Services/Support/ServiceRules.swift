//
//  ServiceRules.swift
//  BelloHub
//

import Foundation

/// The rules of the service list and form that have no UI: which names and prices are accepted, how a draft becomes a
/// `Service`, which choices each control offers and how the list is numbered. One owner for each rule (CLAUDE.md
/// section 2); the View and the ViewModel only ask.
enum ServiceRules {
    /// How long before the first visit a patch test can be asked for, in hours.
    static let patchTestHourOptions = [24, 48, 72]

    // MARK: - Checking

    /// Whether `raw` can be the name of a service. Names are unique ignoring case and accents; `id` is the service
    /// being edited, whose own name does not count as taken.
    static func nameCheck(_ raw: String, among services: [Service], editing id: UUID? = nil) -> CatalogNameCheck {
        CatalogNameRules.check(raw, among: services.filter { $0.id != id }.map(\.name))
    }

    /// Everything wrong with the draft, in the order the form shows it. Empty means it can be saved.
    static func issues(
        in draft: ServiceDraft, among services: [Service], editing id: UUID? = nil, locale: Locale
    ) -> [ServiceFormIssue] {
        var found: [ServiceFormIssue] = []
        switch nameCheck(draft.name, among: services, editing: id) {
        case .accepted: break
        case .empty: found.append(.nameEmpty)
        case .tooLong: found.append(.nameTooLong)
        case .duplicate: found.append(.nameTaken)
        }
        if PriceInput(draft.priceText, locale: locale).isInvalid { found.append(.priceInvalid) }
        return found
    }

    // MARK: - Building

    /// The service the draft describes, or nil when it has an issue. `existing` is the service being edited: it keeps
    /// its id and its place in the list; a new one goes after the last.
    static func build(
        _ draft: ServiceDraft, among services: [Service], editing existing: Service? = nil, locale: Locale,
        makeID: () -> UUID = UUID.init
    ) -> Service? {
        guard issues(in: draft, among: services, editing: existing?.id, locale: locale).isEmpty,
              let name = nameCheck(draft.name, among: services, editing: existing?.id).acceptedName else { return nil }
        let aftercare = draft.aftercareText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Service(
            id: existing?.id ?? makeID(),
            name: name,
            category: OnboardingRules.cleaned(draft.category),
            durationMinutes: draft.minutes,
            priceAmount: PriceInput(draft.priceText, locale: locale).amount,
            priceDisplay: draft.priceDisplay,
            followUpWeeks: draft.followUpWeeks,
            remindBeforeAfterPhotos: draft.remindsPhotos,
            aftercareTemplate: draft.sharesAftercare ? aftercare : nil,
            isActive: draft.isActive,
            position: existing?.position ?? PositionRules.next(after: services),
            contraindications: unique(draft.contraindications),
            requiresPatchTest: draft.requiresPatchTest,
            patchTestHoursBefore: draft.patchTestHoursBefore
        )
    }

    /// The tokens without blanks or repeats, in the order given.
    private static func unique(_ tokens: [String]) -> [String] {
        var seen: Set<String> = []
        return tokens.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    // MARK: - Choices the form offers

    /// The categories she already uses, in the order they first appear, plus `current` when it is new. A category is
    /// the same one ignoring case and accents ("facial" and "Facial").
    static func categories(among services: [Service], including current: String = "") -> [String] {
        var seen: Set<String> = []
        return (services.sorted { $0.position < $1.position }.map(\.category) + [current])
            .map { OnboardingRules.cleaned($0) }
            .filter { !$0.isEmpty && seen.insert(OnboardingRules.comparisonKey($0)).inserted }
    }

    /// The category a new service starts with: the one most services use, the earliest on a tie. Empty when there are
    /// no services yet.
    static func suggestedCategory(among services: [Service]) -> String {
        let counts = Dictionary(grouping: services.map { OnboardingRules.comparisonKey($0.category) }, by: { $0 })
            .mapValues(\.count)
        func uses(_ category: String) -> Int { counts[OnboardingRules.comparisonKey(category)] ?? 0 }
        return categories(among: services).max { uses($0) < uses($1) } ?? ""
    }

    /// The durations the menu offers; a duration that is not on the list (an imported 55 minutes) stays a choice.
    static func durationOptions(including current: Int) -> [Int] {
        OnboardingRules.durationOptions.contains(current)
            ? OnboardingRules.durationOptions : (OnboardingRules.durationOptions + [current]).sorted()
    }

    /// The follow-up choices; a value that is not on the list stays a choice.
    static func followUpOptions(including current: Int?) -> [Int] {
        guard let current, !OnboardingRules.followUpWeekOptions.contains(current) else {
            return OnboardingRules.followUpWeekOptions
        }
        return (OnboardingRules.followUpWeekOptions + [current]).sorted()
    }

    static func patchTestHourOptions(including current: Int) -> [Int] {
        patchTestHourOptions.contains(current) ? patchTestHourOptions : (patchTestHourOptions + [current]).sorted()
    }

    // MARK: - The list

    /// The list in display order: by position, then by name so equal positions never swap between loads.
    static func ordered(_ services: [Service]) -> [Service] {
        services.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    /// `service` switched on or off. Nothing else changes.
    static func setting(_ service: Service, active: Bool) -> Service {
        var changed = service
        changed.isActive = active
        return changed
    }
}
