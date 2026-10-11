//
//  RecoveryKeyView.swift
//  BelloHub
//

import SwiftUI

/// 7.9 Recovery key, as Privacy opens it. Reads the Services from the environment and hands them to
/// `RecoveryKeyContentView`, which owns the ViewModel.
struct RecoveryKeyView: View {
    @Environment(RecoveryKeyService.self) private var service
    @Environment(ProfileService.self) private var profile

    var body: some View {
        RecoveryKeyContentView(service: service, businessName: profile.profile?.publicName ?? "")
    }
}

#Preview {
    NavigationStack { RecoveryKeyView() }
        .environment(RecoveryKeyService(keyManager: KeyManager()))
        .environment(ProfileService(vault: VaultService(repository: nil)))
}
