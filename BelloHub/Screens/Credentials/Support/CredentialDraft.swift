//
//  CredentialDraft.swift
//  BelloHub
//

import Foundation

/// The credential form while she edits it: the year is text until `CredentialRules` reads it.
struct CredentialDraft: Equatable, Sendable {
    var title = ""
    var institution = ""
    var yearText = ""

    init() {}

    init(_ credential: Credential, locale: Locale) {
        title = credential.title
        institution = credential.institution
        yearText = credential.year.map { $0.formatted(.number.locale(locale).grouping(.never)) } ?? ""
    }
}
