//
//  LegalTextBlock.swift
//  BelloHub
//

/// One piece of a legal text as the screen draws it. The legal drafts use a small slice of Markdown: a title,
/// paragraphs with `**bold**`, numbered points and `☐` lines. The strings are Markdown, converted by
/// `LegalTextRenderer.attributed(_:)`.
enum LegalTextBlock: Hashable, Sendable {
    case paragraph(String)
    case numbered(Int, String)
    /// A line that starts with `☐` in the text (an agreement the person ticks). The screen draws its own box.
    case checkbox(String)
}
