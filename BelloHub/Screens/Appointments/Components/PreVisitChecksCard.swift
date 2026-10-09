//
//  PreVisitChecksCard.swift
//  BelloHub
//

import SwiftUI

/// The checks before a visit as lines with an icon: the service against the health form, the health form, the consent
/// and the patch test. Every line says its meaning in words; the icon and color only repeat it. It informs and never
/// blocks (D16), and it shows no answer of the health form, only whether a warning applies.
struct PreVisitChecksCard: View {
    let checklist: PreVisitChecklist
    let serviceName: String
    let formatters: Formatters
    let now: Date
    @Environment(\.locale) private var locale

    private enum Tone {
        case good
        case warning
        case neutral

        var foreground: Color {
            switch self {
            case .good: Palette.sageText
            case .warning: Palette.amberText
            case .neutral: Palette.ink2
            }
        }

        var icon: Icon {
            switch self {
            case .good: .check
            case .warning: .alert
            case .neutral: .info
            }
        }
    }

    private struct Line: Identifiable {
        let id: String
        let tone: Tone
        let text: Text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                if index > 0 {
                    Rectangle().fill(Palette.hairline).frame(height: 1).accessibilityHidden(true)
                }
                HStack(alignment: .firstTextBaseline, spacing: Spacing.row) {
                    Image(icon: line.tone.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(line.tone.foreground)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    line.text
                        .font(Typography.meta)
                        .foregroundStyle(line.tone.foreground)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, Spacing.row)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("preVisit.line.\(line.id)")
            }
        }
        .padding(.horizontal, Spacing.md)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(Palette.hairline) }
        .accessibilityIdentifier("preVisit.checks")
    }

    // MARK: - Lines

    private var lines: [Line] {
        [contraindicationLine, healthFormLine, consentLine, patchTestLine].compactMap { $0 }
    }

    private var contraindicationLine: Line? {
        let service = serviceName
        switch checklist.contraindications {
        case .noneListed:
            return nil
        case .noHealthForm:
            return Line(id: "contraindications", tone: .warning, text: text(
                "preVisit.contra.noForm",
                "No health form on record, so the contraindications of \(service) could not be checked."
            ))
        case .clear:
            return Line(id: "contraindications", tone: .good, text: text(
                "preVisit.contra.clear", "Checked against \(service): no contraindications in her health form."
            ))
        case .warnings(let matches, _):
            let list = formatters.list(matches.map(matchText))
            return Line(id: "contraindications", tone: .warning, text: text(
                "preVisit.contra.warning",
                "\(service) is marked not suitable for: \(list). Review her health form first. This does not block you."
            ))
        }
    }

    private var healthFormLine: Line {
        guard let signed = checklist.healthFormSignedAt else {
            return Line(id: "healthForm", tone: .neutral, text: Text("preVisit.form.none"))
        }
        let date = formatters.recentDate(signed, now: now)
        if checklist.healthFormReviewDue {
            return Line(id: "healthForm", tone: .warning, text: text(
                "preVisit.form.due", "Health form signed \(date). It is time to ask her to review it."
            ))
        }
        return Line(id: "healthForm", tone: .good, text: text("preVisit.form.signed", "Health form signed \(date)."))
    }

    private var consentLine: Line {
        guard let signed = checklist.consentSignedAt else {
            return Line(id: "consent", tone: .neutral, text: Text("preVisit.consent.none"))
        }
        let date = formatters.recentDate(signed, now: now)
        return Line(id: "consent", tone: .good, text: text("preVisit.consent.signed", "ConsentRecord signed \(date)."))
    }

    private var patchTestLine: Line {
        let service = serviceName
        switch checklist.patchTest {
        case .notRequired:
            return Line(id: "patchTest", tone: .good, text: text(
                "preVisit.patch.notRequired", "\(service) does not ask for a patch test."
            ))
        case .missing:
            return Line(id: "patchTest", tone: .warning, text: text(
                "preVisit.patch.missing", "No patch test on record. \(service) asks for one."
            ))
        case .stillObserving(let until):
            let when = formatters.dateTime(until)
            return Line(id: "patchTest", tone: .warning, text: text(
                "preVisit.patch.observing", "The patch test is still being watched until \(when)."
            ))
        case .clear(let testedAt):
            let date = formatters.recentDate(testedAt, now: now)
            return Line(id: "patchTest", tone: .good, text: text(
                "preVisit.patch.clear", "Patch test \(date): no reaction."
            ))
        case .reaction(let testedAt, _):
            let date = formatters.recentDate(testedAt, now: now)
            return Line(id: "patchTest", tone: .warning, text: text(
                "preVisit.patch.reaction", "Patch test \(date): the skin reacted. Look at it before you start."
            ))
        }
    }

    private func matchText(_ line: ContraindicationLine) -> String {
        switch line {
        case .answer(let question, let option):
            option.map { "\(question): \($0)" } ?? question
        case .minor:
            String(localized: "preVisit.contra.minor", locale: locale)
        }
    }

    private func text(_ key: StaticString, _ defaultValue: String.LocalizationValue) -> Text {
        Text(LocalizedStringResource(key, defaultValue: defaultValue).localized(in: locale))
    }
}
