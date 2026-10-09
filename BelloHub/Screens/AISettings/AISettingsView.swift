//
//  AISettingsView.swift
//  BelloHub
//

import SwiftUI

/// 7.5 AISettings: where the assistant runs, what it does and never does, and her preferences. Pushed from More (the
/// More row is wired by the coordinator). Everything is on this iPhone (D23): cloud help is shown, switched off and
/// marked "Not available yet", and review before saving is on and locked. A thin wrapper: it reads the replaceable
/// voice technology and the profile from the environment and hands them to the content, which owns the ViewModel.
struct AISettingsView: View {
    @Environment(ProfileService.self) private var profile
    @Environment(\.voiceCapture) private var voice
    @Environment(\.locale) private var locale

    var body: some View {
        AISettingsContentView(profile: profile, voice: voice, locale: locale)
    }
}

#if DEBUG
#Preview {
    NavigationStack { AISettingsView() }
        .environment(ProfileService(vault: VaultService(repository: nil)))
}
#endif
