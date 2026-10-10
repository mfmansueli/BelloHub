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

    /// "1 client", "12 clients": the noun with its number, picked by the language's own plural rules. Choosing between
    /// the singular and the plural noun by `count == 1` is wrong in most of the fourteen localizations: Arabic has six
    /// forms (an 11th client takes the singular accusative), French and Portuguese treat 0 as singular, and the German
    /// plural word "Kundschaft" is a collective that cannot follow a number at all.
    func countText(_ count: Int, in locale: Locale) -> String {
        let resource: LocalizedStringResource = switch self {
        case .client: LocalizedStringResource("term.client.count", defaultValue: "\(count) clients")
        case .patient: LocalizedStringResource("term.patient.count", defaultValue: "\(count) patients")
        case .student: LocalizedStringResource("term.student.count", defaultValue: "\(count) students")
        case .guest: LocalizedStringResource("term.guest.count", defaultValue: "\(count) guests")
        }
        return String(localized: resource.localized(in: locale))
    }
}
