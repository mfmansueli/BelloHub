//
//  ClientTerm.swift
//  BelloHub
//

import Foundation

/// What the professional calls the people she serves. It replaces "client" across the **professional's** app (the
/// public page keeps neutral wording, docs/07-LOCALIZATION.md section 4).
enum ClientTerm: String, PersistedEnum, Identifiable {
    case client
    case patient
    case student
    case guest

    var id: String { rawValue }

    static let fallback = ClientTerm.client

    /// "client", "patient"... in the reader's language, as a noun for one person.
    var singular: LocalizedStringResource {
        switch self {
        case .client: "term.client.singular"
        case .patient: "term.patient.singular"
        case .student: "term.student.singular"
        case .guest: "term.guest.singular"
        }
    }

    /// The same noun for several people.
    var plural: LocalizedStringResource {
        switch self {
        case .client: "term.client.plural"
        case .patient: "term.patient.plural"
        case .student: "term.student.plural"
        case .guest: "term.guest.plural"
        }
    }

    /// The noun for one person, in `locale`, with its first letter capitalized: a title or a button.
    func titleSingular(in locale: Locale) -> String {
        String(localized: singular.localized(in: locale)).capitalizedFirstLetter(in: locale)
    }

    /// The noun for several people, in `locale`, with its first letter capitalized: a tab or a screen title.
    func titlePlural(in locale: Locale) -> String {
        String(localized: plural.localized(in: locale)).capitalizedFirstLetter(in: locale)
    }

    /// The noun for several people, as written inside a sentence.
    func pluralText(in locale: Locale) -> String {
        String(localized: plural.localized(in: locale))
    }

    /// The noun for one person, as written inside a sentence.
    func singularText(in locale: Locale) -> String {
        String(localized: singular.localized(in: locale))
    }
}
