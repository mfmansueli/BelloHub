//
//  LegalText.swift
//  BelloHub
//

/// One version of one legal document in one localization, as it is bundled (`legal/<document>/<localization>/
/// <version>.md`): the header facts and the body, with the `{{PLACEHOLDERS}}` still in it. The text a person signs is
/// the body of one `LegalText`, so a signature stores `version` and `localization` and nothing more is needed to show
/// it again exactly (ASSUMPTION-24).
struct LegalText: Hashable, Sendable {
    let document: LegalDocument
    /// The localization this text is written in. It can differ from the one asked for: a document missing in a
    /// localization falls back to `en`, and the signature must store the language that was actually read.
    let localization: String
    /// The version in the file name, `2026-10`. A changed text is a new file and a new version.
    let version: String
    let region: String
    /// `draft` or `reviewed`.
    let status: String
    let framework: String
    /// Markdown, header removed.
    let body: String
}
