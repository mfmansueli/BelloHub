//
//  ScreenStateView.swift
//  BelloHub
//

import SwiftUI

/// The system states of a screen that loads data (7.11): skeletons while it loads, the error with a retry, the empty
/// state the caller defines, and the content. `prefix` is the screen's identifier prefix (`followUps` gives
/// `followUps.loading` and `followUps.error`; the empty state carries its own identifier).
struct ScreenStateView<Empty: View, Content: View>: View {
    let phase: ScreenPhase
    let prefix: String
    var rows = 3
    var retry: (() -> Void)?
    @ViewBuilder var empty: Empty
    @ViewBuilder var content: Content

    var body: some View {
        switch phase {
        case .loading:
            ListLoadingView(rows: rows)
                .accessibilityIdentifier("\(prefix).loading")
        case .failed(let message):
            EmptyState(
                icon: .alert, title: Text("appointment.error.title"), message: Text(verbatim: message),
                actionTitle: retry == nil ? nil : "scheduling.tryAgain", action: retry
            )
            .accessibilityIdentifier("\(prefix).error")
        case .empty:
            empty
        case .content:
            content
        }
    }
}
