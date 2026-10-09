//
//  QuickRepliesView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 6.9 QuickReplies. An S5 slice replaces it with the real screen (same name and `init()`, in its
/// feature folder) and deletes this file. Nothing here is meant to ship.
struct QuickRepliesView: View {
    var body: some View {
        Text(verbatim: "QuickRepliesView")
            .accessibilityIdentifier("quickReplies.placeholder")
    }
}

#Preview {
    NavigationStack { QuickRepliesView() }
}
