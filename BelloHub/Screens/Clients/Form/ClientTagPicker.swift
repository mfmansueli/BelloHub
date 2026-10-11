//
//  ClientTagPicker.swift
//  BelloHub
//

import SwiftUI

/// "Tags": her tags as chips she taps to put on or take off this client, and "+ New tag" to make one on the spot. The
/// new tag is saved in her setup (it is not private to this client) and selected here.
struct ClientTagPicker: View {
    let tags: [Tag]
    let selected: [UUID]
    /// `newClient` or `clientEdit`: the first part of every identifier.
    let idPrefix: String
    let onToggle: (UUID) -> Void
    let onCreate: (String) -> Void

    @State private var showsNewTag = false
    @State private var newTagName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("clientForm.tags")
                .font(Typography.metaStrong)
                .foregroundStyle(Palette.ink2)
                .accessibilityAddTraits(.isHeader)
            FlowLayout {
                ForEach(tags) { tag in
                    let isSelected = selected.contains(tag.id)
                    Button { onToggle(tag.id) } label: { Text(verbatim: tag.name) }
                        .buttonStyle(.belloChip(selected: isSelected))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier("\(idPrefix).tag.\(tag.id.uuidString)")
                }
                Button { showsNewTag = true } label: { Text("onb.tags.new") }
                    .buttonStyle(.belloChip(selected: false))
                    .accessibilityIdentifier("\(idPrefix).newTagButton")
            }
        }
        .alert(Text("onb.tags.newTitle"), isPresented: $showsNewTag) {
            TextField(text: $newTagName) { Text("onb.tags.namePrompt") }
            Button { commit() } label: { Text("onb.tags.add") }
            Button(role: .cancel) { newTagName = "" } label: { Text("common.cancel") }
        }
    }

    private func commit() {
        onCreate(newTagName)
        newTagName = ""
    }
}
