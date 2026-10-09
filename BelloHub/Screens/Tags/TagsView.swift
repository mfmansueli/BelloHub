//
//  TagsView.swift
//  BelloHub
//

import SwiftUI

/// 6.12 Tags. The labels she puts on clients: each with its color and how many people carry it. Tap a tag to rename,
/// recolor or delete it; swipe to delete; Edit reorders. A native `List`, because dragging, swipe actions and the
/// edit-mode controls come with it and work with VoiceOver, Switch Control and Dynamic Type for free.
struct TagsView: View {
    @State private var viewModel: TagsViewModel
    @State private var editor: TagEditorMode?
    @State private var pendingDeletion: Tag?

    init(profile: ProfileService, clients: (any ClientRepository)?) {
        _viewModel = State(initialValue: TagsViewModel(profile: profile, clients: clients))
    }

    var body: some View {
        content
            .background(Palette.bg)
            .navigationTitle(Text("tags.title"))
            .navigationBarTitleDisplayMode(.large)
            .task { await viewModel.loadAsync() }
            .sheet(item: $editor) { mode in
                TagEditorSheet(mode: mode, viewModel: viewModel)
            }
            .tagDeletionDialog(
                $pendingDeletion, clientCount: viewModel.clientCount(for:),
                onConfirm: { tag in Task { await viewModel.delete(tag) } }
            )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.showsEmptyState {
            EmptyState(
                icon: .tag, title: "tags.empty.title", message: "tags.empty.message", actionTitle: "tags.new",
                action: { editor = .add }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("tags.empty")
        } else {
            list
        }
    }

    // MARK: - List

    private var list: some View {
        List {
            Section {
                Text("tags.subtitle")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // A little inset: at none the first letter of a wrapped line is clipped by the list's edge.
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
            }
            if let message = viewModel.errorMessage {
                Section {
                    ErrorNotice(message: message, actionTitle: "tags.retry", action: viewModel.load)
                        .accessibilityIdentifier("tags.error")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            if let message = viewModel.saveErrorMessage {
                Section {
                    ErrorNotice(message: message, actionTitle: "tags.dismiss", action: viewModel.dismissSaveError)
                        .accessibilityIdentifier("tags.saveError")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            tagsSection
            Section {
                FooterNote(text: "onb.tags.footer", icon: .lock)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.loadAsync() }
        .toolbar {
            if !viewModel.tags.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    EditButton().accessibilityIdentifier("tags.editButton")
                }
            }
        }
    }

    /// The rows are 56 pt tall by themselves, so the list adds no vertical padding of its own.
    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md)
    }

    private var tagsSection: some View {
        Section {
            if viewModel.showsSkeleton {
                ForEach(0..<3, id: \.self) { _ in Skeleton(height: 44).listRowBackground(Palette.surface) }
            }
            ForEach(viewModel.tags) { tag in
                Button { editor = .edit(tag) } label: {
                    TagRow(tag: tag, clientCount: viewModel.clientCount(for: tag))
                }
                .buttonStyle(.plain)
                .listRowBackground(Palette.surface)
                .listRowInsets(rowInsets)
                .accessibilityIdentifier("tags.row.\(tag.id.uuidString)")
                .accessibilityHint(Text("tags.row.hint"))
            }
            .onMove { source, destination in viewModel.move(from: source, to: destination) }
            .onDelete { offsets in
                // The swipe and the edit-mode minus both land here; she is asked before anything is deleted.
                pendingDeletion = offsets.first.map { viewModel.tags[$0] }
            }
            Button { editor = .add } label: {
                HStack(spacing: Spacing.row) {
                    Image(icon: .plus)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text("tags.new").font(Typography.bodyStrong)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Palette.roseText)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Palette.surface)
            .listRowInsets(rowInsets)
            .accessibilityIdentifier("tags.newButton")
        } header: {
            Text("tags.section.yours")
                .font(Typography.section).foregroundStyle(Palette.ink)
                .textCase(nil)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

#Preview {
    NavigationStack {
        TagsView(profile: ProfileService(vault: VaultService(repository: nil)), clients: nil)
    }
}
