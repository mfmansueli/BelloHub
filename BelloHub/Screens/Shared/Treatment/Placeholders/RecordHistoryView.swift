//
//  RecordHistoryView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 4.7 RecordHistory. An S7 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct RecordHistoryView: View {
    let clientID: UUID
    var body: some View {
        Text(verbatim: "RecordHistoryView")
            .accessibilityIdentifier("recordHistory.placeholder")
    }
}
