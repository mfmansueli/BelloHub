//
//  LegalNoticeLibrary.swift
//  BelloHub
//

/// Where the terms and the privacy policy come from, for Privacy and security (7.7).
protocol LegalNoticeLibrary: Sendable {
    /// The newest version written in `localization`, or, when that language has none, the newest in English.
    func latest(_ notice: LegalNotice, localization: AppLocalization) throws -> LegalNoticeText
}
