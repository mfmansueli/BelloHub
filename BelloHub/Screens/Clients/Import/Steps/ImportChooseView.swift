//
//  ImportChooseView.swift
//  BelloHub
//

import SwiftUI

/// "Choose clients": every person the source found, all selected, in a native list (lazy, so 2,000 rows stay fast).
/// She can untick anyone, select all or clear, and sees how many will be imported before she taps the button. Rows
/// that cannot be imported are listed apart with the reason. The free-registration limit is explained here when the
/// batch is larger than what is left (D42). At accessibility text sizes the notice and the count move from the bottom
/// bar into the list (a plain footer under the people, not a box), so the bar stays one button and the people stay on
/// screen.
struct ImportChooseView: View {
    let viewModel: ImportClientsViewModel
    let term: ClientTerm
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLarge: Bool { dynamicTypeSize.isAccessibilitySize }
    private var showsLimitNotice: Bool { viewModel.fit.needsPlan && !viewModel.readyEntries.isEmpty }

    var body: some View {
        List {
            if viewModel.readyEntries.isEmpty {
                emptyState
            } else {
                Section {
                    ForEach(viewModel.readyEntries) { entry in
                        ImportEntryRow(
                            entry: entry, phoneText: viewModel.phoneText(for: entry),
                            isSelected: viewModel.isSelected(entry.id), action: { viewModel.toggle(entry.id) }
                        )
                        .listRowBackground(Palette.surface)
                        .listRowSeparatorTint(Palette.hairline)
                    }
                } header: {
                    chooseHeader
                } footer: {
                    if isLarge && showsLimitNotice { limitText }
                }
            }
            if !viewModel.skippedEntries.isEmpty { skippedSection }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom) { actionBar }
    }

    // MARK: - Sections

    private var chooseHeader: some View {
        let layout = isLarge
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Spacing.row))
        return layout {
            Text(LocalizedStringResource(
                "import.choose.title", defaultValue: "Choose \(term.pluralText(in: locale))"
            ).localized(in: locale))
                .font(Typography.metaStrong).foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importClients.choose.title")
            if isLarge { selectionCount }
            if !isLarge { Spacer(minLength: Spacing.sm) }
            Button { viewModel.toggleAll() } label: {
                Text(viewModel.allSelected ? "import.clearAll" : "import.selectAll")
                    .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget)
            }
            .accessibilityIdentifier("importClients.selectAllButton")
        }
        .textCase(nil)
    }

    private var skippedSection: some View {
        Section {
            ForEach(viewModel.skippedEntries) { entry in
                ImportSkippedRow(entry: entry)
                    .listRowBackground(Palette.surface)
                    .listRowSeparatorTint(Palette.hairline)
            }
        } header: {
            Text(LocalizedStringResource(
                "import.skipped.title", defaultValue: "\(viewModel.skippedEntries.count) skipped"
            ).localized(in: locale))
                .font(Typography.metaStrong).foregroundStyle(Palette.ink2).textCase(nil)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("importClients.skipped.title")
        } footer: {
            Text("import.skipped.footer").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
    }

    private var emptyState: some View {
        EmptyState(icon: .user, title: "import.choose.empty.title", message: "import.choose.empty.message")
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityIdentifier("importClients.choose.empty")
    }

    // MARK: - Action bar

    private var actionBar: some View {
        VStack(spacing: Spacing.sm) {
            if let problem = viewModel.problem {
                InlineNotice(style: .warning, title: problem.title, message: problem.message)
                    .accessibilityIdentifier("importClients.problem")
            }
            if !isLarge && showsLimitNotice { limitNotice }
            if !isLarge && !viewModel.readyEntries.isEmpty { selectionCount }
            importButton
        }
        .padding(.horizontal, Spacing.gutter)
        .padding(.vertical, Spacing.md)
        .frame(maxWidth: .infinity)
        .background(Palette.bg)
        .motionBar()
    }

    private var selectionCount: some View {
        Text(LocalizedStringResource(
            "import.choose.count",
            defaultValue: "\(viewModel.selection.count) of \(viewModel.readyEntries.count) selected"
        ).localized(in: locale))
            .font(Typography.footnoteStrong).foregroundStyle(Palette.ink2)
            .accessibilityIdentifier("importClients.selectionCount")
    }

    /// Fewer free registrations than chosen clients: says how many go through now and that a plan adds the rest.
    private var limitNotice: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            limitHeadline.font(Typography.metaStrong).foregroundStyle(Palette.amberText)
            Text("import.choose.partial.detail").font(Typography.footnote).foregroundStyle(Palette.amberText)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.amberBg, in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("importClients.limitNotice")
    }

    /// The same message at accessibility sizes: plain text under the list, where it scrolls with the people.
    private var limitText: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            limitHeadline.font(Typography.metaStrong).foregroundStyle(Palette.ink)
            Text("import.choose.partial.detail").font(Typography.footnote).foregroundStyle(Palette.ink2)
        }
        .textCase(nil)
        .accessibilityIdentifier("importClients.limitNotice")
    }

    private var limitHeadline: Text {
        let covered = viewModel.fit.willImport
        let chosen = viewModel.selection.count
        return Text(LocalizedStringResource(
            "import.choose.partial",
            defaultValue: "Your free registrations cover \(covered) of the \(chosen) you chose."
        ).localized(in: locale))
    }

    private var importButton: some View {
        Button { viewModel.importSelectedClients() } label: {
            if viewModel.selection.isEmpty {
                Text("import.button.chooseOne")
            } else {
                Text(importTitle)
            }
        }
        .buttonStyle(.belloPrimary)
        .disabled(!viewModel.canImport)
        .accessibilityIdentifier("importClients.importButton")
    }

    /// "Import 4 clients", with the number and the noun agreeing in the reader's language.
    private var importTitle: LocalizedStringResource {
        let counted = BidiIsolate.wrap(term.countText(viewModel.selection.count, in: locale))
        return LocalizedStringResource("import.button.importCount", defaultValue: "Import \(counted)")
            .localized(in: locale)
    }
}
