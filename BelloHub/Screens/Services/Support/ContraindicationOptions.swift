//
//  ContraindicationOptions.swift
//  BelloHub
//

import Foundation

/// What a service can list as a contraindication, drawn from the same health-form catalog `ContraindicationMatcher`
/// checks against (so a service can only warn about something the form really asks), plus the one thing that comes
/// from the form itself: a client under 18. Pure: the catalog and the words come in as arguments.
enum ContraindicationOptions {
    /// The group the picker puts the "under 18" option in.
    static let aboutTheClientGroupID = "client"

    /// The picker's groups, in the order the form asks its questions. Questions that cannot be decided from an answer
    /// (free text) have no option, so they have no group.
    static func groups(in catalog: HealthFormCatalog, minorGroupTitle: String, minorTitle: String)
        -> [ContraindicationGroup] {
        var order: [String] = []
        var byQuestion: [String: (title: String, options: [ContraindicationOption])] = [:]
        for choice in ContraindicationMatcher.choices(in: catalog) {
            let questionKey = choice.token.split(separator: ".", maxSplits: 1).first.map(String.init) ?? choice.token
            let title = choice.optionName ?? choice.questionName
            let summary = choice.optionName.map { "\(choice.questionName) · \($0)" } ?? choice.questionName
            if byQuestion[questionKey] == nil { order.append(questionKey) }
            byQuestion[questionKey, default: (choice.questionName, [])].options
                .append(ContraindicationOption(token: choice.token, title: title, summary: summary))
        }
        let groups = order.compactMap { key in
            byQuestion[key].map { ContraindicationGroup(id: key, title: $0.title, options: $0.options) }
        }
        let minor = ContraindicationOption(
            token: ContraindicationMatcher.minorToken, title: minorTitle, summary: minorTitle
        )
        return [ContraindicationGroup(id: aboutTheClientGroupID, title: minorGroupTitle, options: [minor])] + groups
    }

    /// The text for one token: its summary when the catalog knows it, the token itself when it does not (a note from a
    /// newer version of the app is shown as it was written, never dropped).
    static func summary(for token: String, in groups: [ContraindicationGroup]) -> String {
        groups.lazy.flatMap(\.options).first { $0.token == token }?.summary ?? token
    }

    /// `selected` in the order the picker lists them, with any token the catalog does not know after them.
    static func ordered(_ selected: [String], in groups: [ContraindicationGroup]) -> [String] {
        let known = groups.flatMap(\.options).map(\.token)
        let chosen = Set(selected)
        let unknown = selected.filter { !known.contains($0) }
        return known.filter { chosen.contains($0) } + unknown
    }

    /// `token` ticked or unticked.
    static func toggling(_ token: String, in selected: [String]) -> [String] {
        selected.contains(token) ? selected.filter { $0 != token } : selected + [token]
    }
}
