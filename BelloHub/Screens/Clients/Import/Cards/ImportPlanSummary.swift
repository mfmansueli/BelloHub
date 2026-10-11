//
//  ImportPlanSummary.swift
//  BelloHub
//

import SwiftUI

/// "Before you import" (routine item 9, D42): the numbers of `ImportPlan` as label and value rows (new registrations,
/// already in her list, free registrations left, registered now, waiting for a plan) and one sentence that says what
/// happens to the rest. Shown above the people on the choose step, so she reads it before the import button. The
/// figures are label/value pairs on purpose: a count beside a label needs no plural agreement in fourteen languages.
struct ImportPlanSummary: View {
    let plan: ImportPlan
    let limit: Int

    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.row) {
            Text("import.plan.title")
                .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            ListCard(dividerInset: Spacing.md) {
                figure("import.plan.new", value: count(plan.newClients), identifier: "importClients.plan.new")
                if plan.alreadyInList > 0 {
                    figure("import.plan.duplicates", value: count(plan.alreadyInList),
                           identifier: "importClients.plan.duplicates")
                }
                if !plan.isUnlimited {
                    figure("import.plan.freeLeft", value: freeLeftValue, identifier: "importClients.plan.freeLeft")
                    if plan.needsPlan {
                        figure("import.plan.now", value: count(plan.registeredNow),
                               identifier: "importClients.plan.now")
                        figure("import.plan.waiting", value: count(plan.waiting),
                               identifier: "importClients.plan.waiting")
                    }
                }
            }
            outcome
            if !plan.checkedDuplicates {
                Text("import.plan.unchecked").font(Typography.footnote).foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("importClients.plan.unchecked")
            }
        }
    }

    // MARK: - Parts

    /// One figure: the label on the leading side, the number on the trailing side; stacked at accessibility sizes so a
    /// long German label never squeezes the number.
    private func figure(_ label: LocalizedStringKey, value: String, identifier: String) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.sm))
        return layout {
            Text(label).font(Typography.body).foregroundStyle(Palette.ink)
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: Spacing.sm) }
            Text(verbatim: value).font(Typography.bodyStrong).foregroundStyle(Palette.ink).monospacedDigit()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.row)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    /// What confirming does, in one sentence. Amber when part of the group waits for a plan, so it is never missed.
    @ViewBuilder
    private var outcome: some View {
        switch plan.kind {
        case .nothingChosen:
            EmptyView()
        case .nothingNew:
            notice(.warning, "import.plan.outcome.nothingNew")
        case .allFree:
            let left = plan.freeLeftAfter
            notice(.info, Text(LocalizedStringResource(
                "import.plan.outcome.allFree",
                defaultValue: "Everyone new is registered now. Free registrations left afterwards: \(left)."
            ).localized(in: locale)))
        case .partlyFree:
            notice(.warning, "import.plan.outcome.partly")
        case .needsPlan:
            notice(.warning, Text(LocalizedStringResource(
                "import.plan.outcome.needsPlan",
                defaultValue: """
                Your \(limit) free registrations are used. Nobody new is saved without a plan, and nothing is \
                charged unless you subscribe.
                """
            ).localized(in: locale)))
        case .unlimited:
            notice(.info, "import.plan.outcome.unlimited")
        }
    }

    private func notice(_ style: InlineNotice.Style, _ key: LocalizedStringKey) -> some View {
        notice(style, Text(key))
    }

    private func notice(_ style: InlineNotice.Style, _ text: Text) -> some View {
        InlineNotice(style: style, title: text)
            .accessibilityIdentifier("importClients.plan.outcome")
    }

    // MARK: - Words

    private func count(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private var freeLeftValue: String {
        LocalizedStringResource(
            "import.plan.freeLeftValue", defaultValue: "\(plan.freeLeft) of \(limit)"
        ).resolved(in: locale)
    }
}
