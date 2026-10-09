//
//  AddOnRules.swift
//  BelloHub
//

import Foundation

/// The rules of the add-on list and form that have no UI: which names and prices are accepted, how a draft becomes an
/// `AddOn`, and what clients are shown. One owner for each rule (CLAUDE.md section 2).
enum AddOnRules {
    /// The extra time the form offers, in minutes.
    static let extraMinuteOptions = [5, 10, 15, 20, 30, 45, 60]

    /// Whether `raw` can be the name of an add-on. Names are unique ignoring case and accents; `id` is the add-on being
    /// edited, whose own name does not count as taken.
    static func nameCheck(_ raw: String, among addOns: [AddOn], editing id: UUID? = nil) -> CatalogNameCheck {
        CatalogNameRules.check(raw, among: addOns.filter { $0.id != id }.map(\.name))
    }

    /// Everything wrong with the draft, in the order the form shows it. Empty means it can be saved.
    static func issues(
        in draft: AddOnDraft, among addOns: [AddOn], editing id: UUID? = nil, locale: Locale
    ) -> [AddOnFormIssue] {
        var found: [AddOnFormIssue] = []
        switch nameCheck(draft.name, among: addOns, editing: id) {
        case .accepted: break
        case .empty: found.append(.nameEmpty)
        case .tooLong: found.append(.nameTooLong)
        case .duplicate: found.append(.nameTaken)
        }
        if PriceInput(draft.priceText, locale: locale).isInvalid { found.append(.priceInvalid) }
        return found
    }

    /// The add-on the draft describes, or nil when it has an issue. `existing` keeps its id and place; a new one goes
    /// after the last.
    static func build(
        _ draft: AddOnDraft, among addOns: [AddOn], editing existing: AddOn? = nil, locale: Locale,
        makeID: () -> UUID = UUID.init
    ) -> AddOn? {
        guard issues(in: draft, among: addOns, editing: existing?.id, locale: locale).isEmpty,
              let name = nameCheck(draft.name, among: addOns, editing: existing?.id).acceptedName else { return nil }
        return AddOn(
            id: existing?.id ?? makeID(), name: name, minutes: draft.minutes,
            priceAmount: PriceInput(draft.priceText, locale: locale).amount, isOffered: draft.isOffered,
            position: existing?.position ?? PositionRules.next(after: addOns)
        )
    }

    /// The minutes the menu offers; a value that is not on the list (an old one) stays a choice.
    static func minuteOptions(including current: Int) -> [Int] {
        extraMinuteOptions.contains(current) ? extraMinuteOptions : (extraMinuteOptions + [current]).sorted()
    }

    /// The list in display order: by position, then by name so equal positions never swap between loads.
    static func ordered(_ addOns: [AddOn]) -> [AddOn] {
        addOns.sorted { ($0.position, $0.name) < ($1.position, $1.name) }
    }

    /// What clients can tick when they book: the add-ons that are switched on, in her order.
    static func offered(_ addOns: [AddOn]) -> [AddOn] {
        ordered(addOns).filter(\.isOffered)
    }

    /// `addOn` switched on or off. Nothing else changes.
    static func setting(_ addOn: AddOn, offered: Bool) -> AddOn {
        var changed = addOn
        changed.isOffered = offered
        return changed
    }
}
