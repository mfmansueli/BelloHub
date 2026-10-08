//
//  RecordStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.8 Onb-6b-Record. The adaptive client record: which fields she sees when she registers a treatment, and what a
/// new client is asked before the first visit. Pre-filled from her profession; one tab of chips per profession.
struct RecordStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        OnboardingStepLayout(
            title: Text(LocalizedStringResource(
                "onb.record.title", defaultValue: "What do you want to remember about each \(term)?"
            ).localized(in: locale)),
            subtitle: Text("onb.record.subtitle"), canContinue: viewModel.canContinue,
            identifier: "record", onContinue: viewModel.goNext
        ) {
            if let profession = viewModel.recordProfession {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    professionChips
                    fieldsSection(for: profession)
                    intakeSection(for: profession)
                }
            }
        }
    }

    private var term: String {
        viewModel.draft.clientTerm.singularText(in: locale)
    }

    // MARK: - Sections

    @ViewBuilder
    private var professionChips: some View {
        if viewModel.draft.professions.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(viewModel.draft.professions, id: \.self) { id in
                        Button { viewModel.showRecord(of: id) } label: {
                            Text(verbatim: viewModel.catalog.entry(for: id)?.name ?? "")
                        }
                        .buttonStyle(.belloChip(selected: viewModel.recordProfession == id))
                        .accessibilityAddTraits(viewModel.recordProfession == id ? .isSelected : [])
                        .accessibilityIdentifier("onboarding.record.profession.\(id.rawValue)")
                    }
                }
            }
        }
    }

    private func fieldsSection(for profession: ProfessionID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("onb.record.fields").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                let total = viewModel.fields(of: profession).count
                Text(LocalizedStringResource(
                    "onb.record.count", defaultValue: "\(viewModel.onCount(for: profession)) of \(total) on"
                ).localized(in: locale))
                    .font(Typography.footnote).foregroundStyle(Palette.ink2)
            }
            ListCard(dividerInset: Spacing.md) {
                ForEach(viewModel.fields(of: profession)) { field in
                    ToggleRow(
                        title: field.name,
                        isOn: Binding(
                            get: { viewModel.isFieldOn(field, of: profession) },
                            set: { viewModel.setField(field, of: profession, on: $0) }
                        ),
                        identifier: "onboarding.record.field.\(field.key)"
                    )
                }
            }
            Text("onb.record.fieldsHint").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private func intakeSection(for profession: ProfessionID) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("onb.record.intake").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Spacing.md)
            ListCard(dividerInset: Spacing.md) {
                ForEach(IntakeItem.allCases) { item in
                    ToggleRow(
                        title: title(of: item), subtitle: subtitle(of: item),
                        isOn: Binding(
                            get: { viewModel.isIntakeOn(item, of: profession) },
                            set: { viewModel.setIntake(item, of: profession, on: $0) }
                        ),
                        identifier: "onboarding.record.intake.\(item.rawValue)"
                    )
                }
            }
        }
    }

    private func title(of item: IntakeItem) -> String {
        switch item {
        case .healthHistory: text("onb.record.intake.healthHistory")
        case .consentForm: text("onb.record.intake.consentForm")
        case .patchTestLog: text("onb.record.intake.patchTestLog")
        }
    }

    private func subtitle(of item: IntakeItem) -> String {
        switch item {
        case .healthHistory: text("onb.record.intake.healthHistoryHint")
        case .consentForm: text("onb.record.intake.consentFormHint")
        case .patchTestLog: text("onb.record.intake.patchTestLogHint")
        }
    }

    private func text(_ key: LocalizedStringResource) -> String {
        String(localized: key.localized(in: locale))
    }
}
