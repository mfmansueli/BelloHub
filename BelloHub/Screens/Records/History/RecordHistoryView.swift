//
//  RecordHistoryView.swift
//  BelloHub
//

import SwiftUI

/// 4.7 RecordHistory, pushed as `RecordRoute.history`. It reads the Services from the environment and hands them to
/// `RecordHistoryContentView`, which owns the ViewModel.
struct RecordHistoryView: View {
    let clientID: UUID
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile

    init(clientID: UUID) {
        self.clientID = clientID
    }

    var body: some View {
        RecordHistoryContentView(clientID: clientID, vault: vault, profile: profile)
    }
}
