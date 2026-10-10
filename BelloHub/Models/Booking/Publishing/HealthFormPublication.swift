//
//  HealthFormPublication.swift
//  BelloHub
//

/// What the booking page needs to ask her health form in the browser (docs/10-WEB-BOOKING.md section 5): the version
/// she asks today and the catalog wording of each booking language. Read from the vault and the bundle by the
/// publishing source; turned into the opaque `intake.template` by `PublishPayloads.intake(_:locales:)`. Which
/// questions she asks is not clinical (it is stored in the clear in the vault too); answers never travel this way.
struct HealthFormPublication: Equatable, Sendable {
    var template: HealthFormTemplate
    /// One catalog per booking language. A language with no catalog file reads English (the provider's rule).
    var catalogs: [AppLocalization: HealthFormCatalog]
    /// The word for "None" of a choices question, per booking language (`health.answer.none`).
    var noneLabels: [AppLocalization: String]
}
