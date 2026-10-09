//
//  LegalNoticeText.swift
//  BelloHub
//

/// One version of one legal notice in one localization, header facts and Markdown body (placeholders still in it).
/// The app never shows the `status` word to her (legal/STATUS.md): it is kept for the Release gate only.
struct LegalNoticeText: Hashable, Sendable {
    let notice: LegalNotice
    let localization: String
    let version: String
    let status: String
    let body: String
}
