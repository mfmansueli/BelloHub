//
//  ExportRecordView.swift
//  BelloHub
//

import SwiftUI

/// PLACEHOLDER for 4.10 ExportRecord. An S7 slice replaces it with the real screen (same name
/// and `init`, in its feature folder) and deletes this file. Not meant to ship.
struct ExportRecordView: View {
    let clientID: UUID
    var body: some View {
        Text(verbatim: "ExportRecordView")
            .accessibilityIdentifier("exportRecord.placeholder")
    }
}
