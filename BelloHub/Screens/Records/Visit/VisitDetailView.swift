//
//  VisitDetailView.swift
//  BelloHub
//

import SwiftUI

/// One visit's full details, pushed from the client record, the photos and "Before you start". It reads the
/// Services from the environment and hands them to the content, which owns the ViewModel.
struct VisitDetailView: View {
    let recordID: UUID
    @Environment(VaultService.self) private var vault
    @Environment(ProfileService.self) private var profile

    var body: some View {
        VisitDetailContentView(recordID: recordID, vault: vault, profile: profile)
    }
}
