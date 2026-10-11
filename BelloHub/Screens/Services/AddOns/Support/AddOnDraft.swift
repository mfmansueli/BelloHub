//
//  AddOnDraft.swift
//  BelloHub
//

import Foundation

/// The add-on form while she edits it: the price is text until `AddOnRules` accepts it.
struct AddOnDraft: Equatable, Sendable {
    var name = ""
    var minutes = 15
    var priceText = ""
    var isOffered = true

    /// A new add-on, offered, adding 15 minutes (the choice the prototype starts on).
    init() {}

    /// The form for an add-on that exists, with the price written the way `locale` writes numbers and without a
    /// thousands separator, so reading it back gives the same amount.
    init(_ addOn: AddOn, locale: Locale) {
        name = addOn.name
        minutes = addOn.minutes
        priceText = addOn.priceAmount.map { $0.formatted(.number.locale(locale).grouping(.never)) } ?? ""
        isOffered = addOn.isOffered
    }
}
