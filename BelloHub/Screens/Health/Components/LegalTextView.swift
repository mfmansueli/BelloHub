//
//  LegalTextView.swift
//  BelloHub
//

import SwiftUI

/// A legal text, drawn as written: a title, paragraphs with their bold words, numbered points and the `☐` lines. The
/// words are never edited here. A text written in a right-to-left language reads right to left even when the app is
/// in another language, so the layout direction follows the text, not the phone.
struct LegalTextView: View {
    let text: RenderedLegalText
    let language: AppLocalization?
    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            if !text.title.isEmpty {
                Text(verbatim: text.title)
                    .font(Typography.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(text.blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, language?.isRightToLeft == true ? .rightToLeft : layoutDirection)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func blockView(_ block: LegalTextBlock) -> some View {
        switch block {
        case .paragraph(let markdown):
            Text(LegalTextRenderer.attributed(markdown)).font(Typography.body).foregroundStyle(Palette.ink)
        case .numbered(let number, let markdown):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(verbatim: "\(number).").font(Typography.bodyStrong).foregroundStyle(Palette.ink2)
                Text(LegalTextRenderer.attributed(markdown)).font(Typography.body).foregroundStyle(Palette.ink)
            }
        case .checkbox(let markdown):
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                // The box is the character the text itself uses; the person ticks the real checkbox below.
                Text(verbatim: "\u{2610}").font(Typography.bodyStrong).foregroundStyle(Palette.ink2)
                    .accessibilityHidden(true)
                Text(LegalTextRenderer.attributed(markdown)).font(Typography.body).foregroundStyle(Palette.ink)
            }
        }
    }
}

#Preview {
    ScrollView {
        LegalTextView(
            text: RenderedLegalText(title: "Consent", blocks: [
                .paragraph("**Who is asking.** Maria is responsible for the information you share here."),
                .numbered(1, "She may collect your health information."),
                .checkbox("I have read this and I agree.")
            ]),
            language: .en
        )
        .padding()
    }
    .background(Palette.bg)
}
