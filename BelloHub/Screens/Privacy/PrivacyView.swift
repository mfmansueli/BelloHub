//
//  PrivacyView.swift
//  BelloHub
//

import SwiftUI

/// 7.7 Privacy and security, as More opens it. Reads the Services from the environment and hands them to
/// `PrivacyContentView`, which owns the ViewModel.
struct PrivacyView: View {
    @Environment(AppLockService.self) private var lock
    @Environment(RecoveryKeyService.self) private var recoveryKey
    @Environment(NotificationSettingsService.self) private var notifications
    @Environment(ProfileService.self) private var profile
    @Environment(KeyManager.self) private var keys

    var body: some View {
        PrivacyContentView(
            lock: lock, recoveryKey: recoveryKey, notifications: notifications,
            localization: profile.profile.flatMap { AppLocalization(rawValue: $0.appLocaleID) } ?? .en,
            inboxKeyID: (try? keys.currentInboxPublicKey())?.keyId
        )
    }
}

#Preview {
    let keys = KeyManager()
    NavigationStack { PrivacyView() }
        .environment(AppLockService(keyManager: keys))
        .environment(RecoveryKeyService(keyManager: keys))
        .environment(NotificationSettingsService(permissions: PermissionService()))
        .environment(ProfileService(vault: VaultService(repository: nil)))
        .environment(keys)
}
