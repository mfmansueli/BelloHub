//
//  Initials.swift
//  BelloHub
//

import Foundation

/// The letters shown in an `Avatar`. Pure and nonisolated so it is tested without a view.
enum Initials {
    /// First letter of the first and last words, in the locale's casing (Turkish "i" becomes "İ").
    /// Scripts without case (Arabic, Devanagari) keep their letters as they are.
    static func make(from name: String, locale: Locale = .current) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        guard let first = words.first else { return "" }
        let picked = words.count > 1 ? [first, words[words.count - 1]] : [first]
        return picked.compactMap { $0.first.map { String($0).uppercased(with: locale) } }.joined()
    }
}
