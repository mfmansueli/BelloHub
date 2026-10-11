//
//  QuickRepliesContentView.swift
//  BelloHub
//

import SwiftUI

/// The list of her quick replies: tap one to read, edit or put back its message; "New reply" adds one of her own. A
/// native `List`, with the loading, error and save-error states the other lists have.
struct QuickRepliesContentView: View {
    @State private var viewModel: QuickRepliesViewModel
    @State private var editor: QuickReplyEditorMode?

    init(service: BookingSetupService, profile: ProfessionalProfile?) {
        _viewModel = State(initialValue: QuickRepliesViewModel(service: service, profile: profile))
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: Spacing.md, bottom: 0, trailing: Spacing.md)
    }

    var body: some View {
        List {
            Section {
                Text("quickReplies.subtitle")
                    .font(Typography.body).foregroundStyle(Palette.ink2)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    // A little inset: at none the first letter of a wrapped line is clipped by the list's edge.
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.sm, bottom: Spacing.sm, trailing: Spacing.sm))
                if let message = viewModel.errorMessage {
                    ErrorNotice(message: message, actionTitle: "bookingSetup.retry", action: viewModel.load)
                        .accessibilityIdentifier("quickReplies.error")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
                if let message = viewModel.saveErrorMessage {
                    ErrorNotice(
                        message: message, actionTitle: "bookingSetup.dismiss", action: viewModel.dismissSaveError
                    )
                        .accessibilityIdentifier("quickReplies.saveError")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            Section {
                if viewModel.showsSkeleton {
                    ForEach(0..<4, id: \.self) { _ in Skeleton(height: 44).listRowBackground(Palette.surface) }
                }
                ForEach(viewModel.replies) { reply in
                    Button { editor = .edit(reply) } label: { QuickReplyRow(reply: reply) }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surface)
                        .listRowInsets(rowInsets)
                        .accessibilityHint(Text("quickReplies.row.hint"))
                        .accessibilityIdentifier("quickReplies.row.\(reply.id.uuidString)")
                }
                if viewModel.hasLoaded && viewModel.errorMessage == nil {
                    Button { editor = .add } label: { AddRowLabel(title: "quickReplies.new") }
                        .buttonStyle(.plain)
                        .listRowBackground(Palette.surface)
                        .listRowInsets(rowInsets)
                        .accessibilityIdentifier("quickReplies.newButton")
                }
            }
            Section {
                FooterNote(text: "quickReplies.note", icon: .info)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.bg)
        .navigationTitle(Text("quickReplies.title"))
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.loadAsync() }
        .task { await viewModel.loadAsync() }
        .sheet(item: $editor) { mode in
            QuickReplyEditorSheet(mode: mode, viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        QuickRepliesContentView(service: BookingSetupService(vault: VaultService(repository: nil)), profile: nil)
    }
}
