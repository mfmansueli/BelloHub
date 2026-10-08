//
//  TerminologyStepView.swift
//  BelloHub
//

import SwiftUI

/// 1.6 Onb-5-Terminology. What she calls the people she serves, and the names she uses for her services and
/// protocols. The first changes the words of the app; the second teaches the voice notes (S7).
struct TerminologyStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showsAddName = false
    @Environment(\.locale) private var locale

    var body: some View {
        OnboardingStepLayout(
            title: Text("onb.terminology.title"), subtitle: Text("onb.terminology.subtitle"),
            canContinue: viewModel.canContinue, identifier: "terminology", onContinue: viewModel.goNext
        ) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                termPicker
                namesCard
                note
            }
        }
        .sheet(isPresented: $showsAddName) {
            AddNameSheet { name, kind in _ = viewModel.addVocabulary(name, kind: kind) }
        }
    }

    // MARK: - Client term

    private var termPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("onb.terminology.term").font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout {
                ForEach(ClientTerm.allCases) { term in
                    Button { viewModel.setClientTerm(term) } label: {
                        Text(verbatim: term.titleSingular(in: locale))
                    }
                    .buttonStyle(.belloChip(selected: viewModel.draft.clientTerm == term))
                    .accessibilityAddTraits(viewModel.draft.clientTerm == term ? .isSelected : [])
                    .accessibilityIdentifier("onboarding.terminology.term.\(term.rawValue)")
                }
            }
        }
    }

    // MARK: - Names

    private var namesCard: some View {
        ListCard(dividerInset: Spacing.md) {
            ForEach(chosenServiceNames, id: \.self) { name in
                nameRow(name, kind: "onb.terminology.kind.service")
            }
            ForEach(viewModel.draft.vocabulary) { term in
                nameRow(term.text, kind: term.kind == .service ? "onb.terminology.kind.service"
                        : "onb.terminology.kind.protocol")
                    .contextMenu {
                        Button(role: .destructive) { viewModel.removeVocabulary(id: term.id) } label: {
                            Text("common.remove")
                        }
                    }
            }
            Button { showsAddName = true } label: {
                HStack(spacing: Spacing.row) {
                    Image(icon: .plus).foregroundStyle(Palette.roseText)
                    Text("onb.terminology.add").font(Typography.body).foregroundStyle(Palette.ink2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("onboarding.terminology.addButton")
        }
    }

    private var chosenServiceNames: [String] {
        viewModel.suggestedServices.filter { viewModel.isServiceSelected($0.key) }.map(\.name)
            + viewModel.draft.customServices.map(\.name)
    }

    private func nameRow(_ name: String, kind: LocalizedStringKey) -> some View {
        HStack(spacing: Spacing.row) {
            Text(verbatim: name).font(Typography.bodyStrong).foregroundStyle(Palette.ink)
            Spacer(minLength: Spacing.sm)
            Text(kind).font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
        .padding(.horizontal, Spacing.md)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }

    private var note: some View {
        HStack(alignment: .top, spacing: Spacing.row) {
            Image(icon: .sparkle).foregroundStyle(Palette.roseDeepText).accessibilityHidden(true)
            Text("onb.terminology.note").font(Typography.meta).foregroundStyle(Palette.roseDeepText)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.roseWash, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
