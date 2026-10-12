//
//  ClientSearch.swift
//  BelloHub
//

import Foundation

/// Search over the client list. A query is split into words and every word has to match something of the client:
/// her name or one of her tags (ignoring case, accents and width, so "maria" finds "María") or her phone number
/// (digits only, so "98123-4410" and "(11) 98123" find "+55 11 98123-4410"). Clinical text is never searched here:
/// notes are sealed in the vault and the list never decrypts them (docs/05-DATA-MODEL.md section 1).
enum ClientSearch {
    /// Characters that may appear around the digits of a typed phone number.
    private static let phoneMarks = Set("+-().")

    /// The clients that match `query`; all of them for an empty query. Order is kept. The client list and the client
    /// pickers (register a visit from Home) share this one rule.
    static func filter<Item>(_ items: [Item], query: String, tags: [Tag], client: (Item) -> Client) -> [Item] {
        let words = words(in: query)
        guard !words.isEmpty else { return items }
        let tagNames = foldedNames(of: tags)
        return items.filter { matches(client($0), words: words, tagNames: tagNames) }
    }

    /// Whether one client matches `query`. Same rule as `filter`, for callers that hold a single client.
    static func matches(_ client: Client, query: String, tags: [Tag]) -> Bool {
        let words = words(in: query)
        guard !words.isEmpty else { return true }
        return matches(client, words: words, tagNames: foldedNames(of: tags))
    }

    // MARK: - Private

    private struct Word {
        let text: String
        /// The digits of the word when it can be part of a phone number ("98123-4410"), otherwise empty.
        let phoneDigits: String
    }

    private static func words(in query: String) -> [Word] {
        query.split(whereSeparator: \.isWhitespace).map { raw in
            let word = String(raw)
            let ascii = DigitNormalizer.ascii(word)
            let digits = DigitNormalizer.digitsOnly(ascii)
            let isPhoneLike = !digits.isEmpty && ascii.allSatisfy { character in
                (character.isASCII && character.isNumber) || phoneMarks.contains(character)
            }
            return Word(text: fold(word), phoneDigits: isPhoneLike ? digits : "")
        }
    }

    private static func matches(_ client: Client, words: [Word], tagNames: [UUID: String]) -> Bool {
        let name = fold(client.name)
        let phone = client.phoneE164.map { DigitNormalizer.digitsOnly($0) } ?? ""
        let ownTags = client.tagIDs.compactMap { tagNames[$0] }
        return words.allSatisfy { word in
            if name.contains(word.text) { return true }
            if !word.phoneDigits.isEmpty, phone.contains(word.phoneDigits) { return true }
            return ownTags.contains { $0.contains(word.text) }
        }
    }

    private static func foldedNames(of tags: [Tag]) -> [UUID: String] {
        Dictionary(tags.map { ($0.id, fold($0.name)) }, uniquingKeysWith: { first, _ in first })
    }

    private static func fold(_ text: String) -> String {
        ClientMerger.comparisonKey(text)
    }
}
