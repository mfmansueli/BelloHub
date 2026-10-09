//
//  QuickReplyRules.swift
//  BelloHub
//

import Foundation

/// Every rule for editing quick replies, pure so it is tested and neither the editor nor its ViewModel repeats it:
/// what a valid reply is, making a new one, putting a built-in one back, and adding a word in curly braces to a
/// message.
enum QuickReplyRules {
    /// The first problem with a reply, or nil. Text is trimmed before it is judged.
    static func issue(title: String, text: String) -> QuickReplyIssue? {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return .nameEmpty }
        if message.isEmpty { return .textEmpty }
        if message.count > QuickReply.maxTextLength { return .textTooLong }
        return nil
    }

    /// A reply of her own, at the end of the list. Nil when `issue` says it is not valid.
    static func making(
        title: String, text: String, among replies: [QuickReply], id: UUID = UUID(), now: Date
    ) -> QuickReply? {
        guard issue(title: title, text: text) == nil else { return nil }
        let position = (replies.map(\.position).max() ?? -1) + 1
        return QuickReply(
            id: id, builtInKey: nil, title: clean(title), text: cleanText(text), position: position, updatedAt: now
        )
    }

    /// `reply` with a new name and text, or nil when `issue` says they are not valid.
    static func updating(_ reply: QuickReply, title: String, text: String, now: Date) -> QuickReply? {
        guard issue(title: title, text: text) == nil else { return nil }
        var updated = reply
        updated.title = clean(title)
        updated.text = cleanText(text)
        updated.updatedAt = now
        return updated
    }

    /// A built-in reply written again as the catalog has it in `localization`; nil for one she wrote.
    static func original(of reply: QuickReply, in localization: AppLocalization, now: Date) -> QuickReply? {
        guard let builtIn = reply.builtIn else { return nil }
        var original = builtIn.reply(in: localization, now: now)
        original.position = reply.position
        return original
    }

    /// Whether a built-in reply differs from the catalog's, so "back to the original" is worth offering.
    static func isEdited(_ reply: QuickReply, in localization: AppLocalization) -> Bool {
        guard let builtIn = reply.builtIn else { return false }
        return reply.text != builtIn.text(in: localization) || reply.title != builtIn.title(in: localization)
    }

    /// `text` with `variable` added at the end, with one space between them when the text does not already end in a
    /// space or a line break.
    static func appending(_ variable: QuickReplyVariable, to text: String) -> String {
        guard let last = text.last else { return variable.token }
        return last.isWhitespace ? text + variable.token : text + " " + variable.token
    }

    // MARK: - Private

    private static func clean(_ title: String) -> String {
        String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(QuickReply.maxTitleLength))
    }

    /// Keeps her line breaks, drops the blank space around the whole message.
    private static func cleanText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
