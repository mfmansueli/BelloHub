//
//  ImportChooseView.swift
//  BelloHub
//

import SwiftUI

/// "Choose clients": every person the source found in a native list (lazy, so 2,000 rows stay fast), the new ones
/// selected and the ones already in her list marked. Above them, "Before you import" (`ImportPlanSummary`) says how
/// many are new, how many free registrations are left and what waits for a plan (D42, routine item 9). She can untick
/// anyone, select all or clear, or "Try a small group" (the first 3, 5 or 10 new people) to see how the import works
/// before bringing everyone. Rows that cannot be imported are listed apart with the reason. The summary scrolls with
/// the list, so at accessibility sizes the bottom bar stays one count and one button.
struct ImportChooseView: View {
    let viewModel: ImportClientsViewModel
    let term: ClientTerm
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var isLarge: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        List {
            if viewModel.readyEntries.isEmpty {
                emptyState
            } else {
                Section {
                    ImportPlanSummary(plan: viewModel.plan, limit: viewModel.usage.limit)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                }
                Section {
                    ForEach(viewModel.readyEntries) { entry in
                        ImportEntryRow(
                            entry: entry, phoneText: viewModel.phoneText(for: entry),
                            isSelected: viewModel.isSelected(entry.id),
                            isAlreadyInList: viewModel.isAlreadyInList(entry), action: { viewModel.toggle(entry.id) }
                        )
                        .listRowBackground(Palette.surface)
                        .listRowSeparatorTint(Palette.hairline)
                    }
                } header: {
                    chooseHeader
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
            if !isLarge { Spacer(minLength: Spacing.sm) }
            if !viewModel.trialChoices.isEmpty { trialMenu }
            Button { viewModel.toggleAll() } label: {
                Text(viewModel.allSelected ? "import.clearAll" : "import.selectAll")
                    .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                    .frame(minHeight: Spacing.touchTarget)
            }
            .accessibilityIdentifier("importClients.selectAllButton")
        }
        .textCase(nil)
    }

    /// "Try a small group": a native menu that selects only the first few new people, so she can see the import work
    /// (and how many free registrations it uses) before bringing the whole list.
    private var trialMenu: some View {
        Menu {
            ForEach(viewModel.trialChoices, id: \.self) { size in
                Button {
                    viewModel.selectTrial(size: size)
                } label: {
                    Text(LocalizedStringResource(
                        "import.plan.trial.first", defaultValue: "First \(size) new"
                    ).localized(in: locale))
                }
                .accessibilityIdentifier("importClients.trial.\(size)")
            }
        } label: {
            Text("import.plan.trial.menu")
                .font(Typography.metaStrong).foregroundStyle(Palette.roseText)
                .frame(minHeight: Spacing.touchTarget)
        }
        .accessibilityIdentifier("importClients.trialMenu")
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
            if !viewModel.readyEntries.isEmpty { selectionCount }
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
