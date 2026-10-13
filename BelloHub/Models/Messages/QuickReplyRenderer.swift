//
//  QuickReplyRenderer.swift
//  BelloHub
//

import Foundation

/// Fills the words of a quick reply (`{name} {service} {date} {time} {link} {address}`) for one client, in the
/// language of the business. Dates and times come from `Formatters`, so they are the locale's own (`{date}` is
/// "Thursday, October 1" without the year, `{time}` follows the locale's clock). In a right-to-left language every
/// filled value is isolated so a name or a time cannot reorder the sentence around it (docs/07-LOCALIZATION.md
/// section 2.5). The link follows `ClientLinkText`: the full address, on its own line, never isolated, whatever the
/// text around `{link}` looks like, so the replies she wrote before that rule existed come out clickable too. The
/// address block (`{address}`) also stands on lines of its own, and disappears with its line when she has none.
enum QuickReplyRenderer {
    /// A word in curly braces: letters only, so a stray brace in her own text is left alone.
    private static var pattern: Regex<(Substring, Substring)> { /\{([A-Za-z]+)\}/ }

    static func render(
        _ template: String, values: QuickReplyValues, formatters: Formatters, isolates: Bool = false
    ) -> String {
        let address = values.address ?? ""
        let text = address.isEmpty ? withoutAddress(template) : template
        var result = ""
        var cursor = text.startIndex
        for match in text.matches(of: pattern) {
            result += text[cursor..<match.range.lowerBound]
            let word = String(match.output.1)
            if let variable = QuickReplyVariable(rawValue: word),
               let value = value(of: variable, values: values, formatters: formatters, isolates: isolates) {
                result += value
            } else {
                result += text[match.range]
            }
            cursor = match.range.upperBound
        }
        result += text[cursor...]
        if !address.isEmpty { result = ClientLinkText.placeOnOwnLine(address, in: result) }
        guard let link = values.link, !link.isEmpty else { return result }
        return ClientLinkText.placeOnOwnLine(link, in: result)
    }

    /// `{address}` taken out when she has no address: a line holding only the word goes with it, and so does the space
    /// the word leaves in a sentence, so the message reads as if it was never there.
    static func withoutAddress(_ text: String) -> String {
        let token = QuickReplyVariable.address.token
        guard text.contains(token) else { return text }
        let lines = text.components(separatedBy: "\n").compactMap { line -> String? in
            guard line.contains(token) else { return line }
            let stripped = line.replacingOccurrences(of: token, with: "")
                .replacingOccurrences(of: "  ", with: " ")
            return stripped.trimmingCharacters(in: .whitespaces).isEmpty ? nil : stripped
        }
        var joined = lines.joined(separator: "\n")
        while joined.contains("\n\n\n") { joined = joined.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return joined.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Every word in curly braces in `text`, known or not, in order, without repeats.
    static func words(in text: String) -> [String] {
        var seen: [String] = []
        for match in text.matches(of: pattern) {
            let word = String(match.output.1)
            if !seen.contains(word) { seen.append(word) }
        }
        return seen
    }

    /// The words in curly braces the app does not know: they are sent as written, and the editor says so.
    static func unknownWords(in text: String) -> [String] {
        words(in: text).filter { QuickReplyVariable(rawValue: $0) == nil }
    }

    // MARK: - Private

    private static func value(
        of variable: QuickReplyVariable, values: QuickReplyValues, formatters: Formatters, isolates: Bool
    ) -> String? {
        switch variable {
        case .name:
            return values.name.map { isolates ? BidiIsolate.wrap($0) : $0 }
        case .service:
            return values.service.map { isolates ? BidiIsolate.wrap($0) : $0 }
        case .date:
            return values.startsAt.map { date in
                let text = formatters.weekdayDayMonth(date)
                return isolates ? BidiIsolate.wrap(text) : text
            }
        case .time:
            return values.startsAt.map { date in
                let text = formatters.time(date)
                return isolates ? BidiIsolate.wrapLeftToRight(text) : text
            }
        case .link:
            return values.link
        case .address:
            return values.address.flatMap { $0.isEmpty ? nil : $0 }
        case .business:
            return values.business.map { isolates ? BidiIsolate.wrap($0) : $0 }
        }
    }
}
