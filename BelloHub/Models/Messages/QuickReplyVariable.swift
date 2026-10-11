//
//  QuickReplyVariable.swift
//  BelloHub
//

/// The words in curly braces a message can use. The names are part of what she types, so they never change and are not
/// translated (docs/07-LOCALIZATION.md section 6).
enum QuickReplyVariable: String, CaseIterable, Identifiable, Sendable {
    case name
    case service
    case date
    case time
    case link
    /// Where she works ("Where you work"): the address lines, the "how to find us" note and a map link, on lines of
    /// their own. Gone, with its line, when she has no address.
    case address

    var id: String { rawValue }

    /// How it is written in a message: `{name}`.
    var token: String { "{\(rawValue)}" }
}
