//
//  ExportRecordView.swift
//  BelloHub
//

import SwiftUI

/// 4.10 ExportRecord, presented as `RecordSheet.exportRecord`. It reads the Services and the replaceable PDF technology
/// from the environment and hands them to `ExportRecordContentView`, which owns the ViewModel.
struct ExportRecordView: View {
    let clientID: UUID
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile
    @Environment(\.recordExporter) private var exporter
    @Environment(\.locale) private var locale

    init(clientID: UUID) {
        self.clientID = clientID
    }

    var body: some View {
        ExportRecordContentView(
            clientID: clientID, vault: vault, profile: profile, exporter: exporter, locale: locale
        )
    }
}
