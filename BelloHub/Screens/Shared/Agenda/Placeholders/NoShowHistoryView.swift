//
//  NoShowHistoryView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 4.11 NoShowHistory. An S6 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct NoShowHistoryView: View {
    let clientID: UUID
    var body: some View {
        Text(verbatim: "NoShowHistoryView")
            .accessibilityIdentifier("noShowHistory.placeholder")
    }
}
