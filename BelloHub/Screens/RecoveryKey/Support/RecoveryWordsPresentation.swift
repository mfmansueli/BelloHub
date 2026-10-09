//
//  RecoveryWordsPresentation.swift
//  BelloHub
//

import Foundation

/// How the 12 words are shown and exported (7.9): masked until revealed, numbered, and the text of the file she
/// saves or prints (with the warning in her language). Pure.
enum RecoveryWordsPresentation {
    static let mask = "••••••"

    struct Cell: Equatable, Identifiable, Sendable {
        let position: Int
        let text: String
        var id: Int { position }
    }

    /// Twelve cells, masked when there is no phrase.
    static func cells(_ phrase: RecoveryPhrase?) -> [Cell] {
        (1...RecoveryPhrase.wordCount).map { position in
            Cell(position: position, text: phrase.map { $0.words[position - 1] } ?? mask)
        }
    }

    /// The text file: a heading, the numbered words, the warning.
    static func fileText(_ phrase: RecoveryPhrase, businessName: String, locale: Locale) -> String {
        let heading = String(localized: "recoveryKey.file.heading", locale: locale)
        let warning = String(localized: "recoveryKey.file.warning", locale: locale)
        let lines = phrase.words.enumerated().map { "\($0.offset + 1). \($0.element)" }
        return ([heading, businessName, ""] + lines + ["", warning]).joined(separator: "\n") + "\n"
    }

    static let fileName = "bellohub-recovery-key.txt"

    /// The restore screen's words as typed, cleaned the way the parser reads them.
    static func typedWordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}
