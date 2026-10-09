//
//  BookingSlug.swift
//  BelloHub
//

import Foundation

/// The address part of her booking link (`bellohub.app/<slug>`): how it is made from a name, and what makes one valid.
/// The rules mirror the server's (`firebase/functions/src/contracts/common.ts`, `SlugSchema`): 3 to 30 characters, a to
/// z, 0 to 9 and hyphens, no hyphen at either end or twice in a row, and not one of the words the web app uses for
/// its own routes.
enum BookingSlug {
    static let lengthRange = 3...30

    /// Routes of the web app and words nobody may own (docs/10-WEB-BOOKING.md section 2), as the server lists them.
    static let reserved: Set<String> = [
        "m", "p", "api", "admin", "app", "www", "help", "support", "static", "assets", "login", "auth", "bookings",
        "book", "status", "privacy", "terms", "legal", "about"
    ]

    // MARK: - Validation

    /// The first problem with `slug`, or nil when it is valid. Does not look at who owns it: that is the server's job.
    static func validate(_ slug: String) -> SlugIssue? {
        if slug.unicodeScalars.contains(where: { !isAllowed($0) }) { return .characters }
        if slug.count < lengthRange.lowerBound { return .tooShort }
        if slug.count > lengthRange.upperBound { return .tooLong }
        if slug.hasPrefix("-") || slug.hasSuffix("-") { return .hyphenEdges }
        if slug.contains("--") { return .doubleHyphen }
        if reserved.contains(slug) { return .reserved }
        return nil
    }

    // MARK: - Making one

    /// What she types, turned into something that can stay in the field: lowercase, accents folded, anything else
    /// turned into one hyphen. A trailing hyphen is kept, because she may be about to type the next word.
    static func sanitizedWhileTyping(_ raw: String) -> String {
        var output = ""
        for scalar in latinized(raw).unicodeScalars {
            if isAllowed(scalar) {
                output.unicodeScalars.append(scalar)
            } else if !output.hasSuffix("-") {
                output.append("-")
            }
        }
        // A leading hyphen never helps; a hyphen at the end is how she separates words.
        return String(output.drop { $0 == "-" }.prefix(lengthRange.upperBound))
    }

    /// A valid slug from a name: "María José Çelik" is `maria-jose-celik`, an Arabic or Hindi name becomes its Latin
    /// reading. Nil when the name has nothing to build from (no letters or digits the system can read).
    static func make(from name: String) -> String? {
        var text = sanitizedWhileTyping(name)
        while text.hasSuffix("-") { text.removeLast() }
        guard !text.isEmpty else { return nil }
        // Too short ("Al"): pad with a neutral word instead of failing, so every name has a suggestion.
        if text.count < lengthRange.lowerBound { text += "-studio" }
        return validate(text) == nil ? text : nil
    }

    /// Up to three suggestions for a professional: her business name, her own name, both together. Reserved words and
    /// duplicates are left out. `fallbackSeed` makes the last resort deterministic in tests.
    static func suggestions(displayName: String, businessName: String, fallbackSeed: Int = 0) -> [String] {
        let both = [displayName, businessName].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")
        var found: [String] = []
        let candidates = [businessName, displayName, both].compactMap { make(from: $0) }
        for candidate in candidates where !found.contains(candidate) {
            found.append(candidate)
        }
        if found.isEmpty { found.append("bello-\(1000 + abs(fallbackSeed) % 9000)") }
        return Array(found.prefix(3))
    }

    // MARK: - Private

    private static func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        (scalar >= "a" && scalar <= "z") || (scalar >= "0" && scalar <= "9") || scalar == "-"
    }

    /// Lowercase Latin letters without accents, whatever the script: Arabic and Devanagari go through the system's
    /// transliteration, which is what a person reading the link aloud would say.
    private static func latinized(_ text: String) -> String {
        let latin = text.applyingTransform(.toLatin, reverse: false) ?? text
        let plain = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        return plain.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
    }
}
