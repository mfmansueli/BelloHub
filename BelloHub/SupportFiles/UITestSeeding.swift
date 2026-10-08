//
//  UITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// Ready-made states for UI tests (`-uiSeed onboarded`). DEBUG only. A test that wants the onboarding itself does
/// not seed: it launches clean and walks it.
enum UITestSeeding {
    static let userID = "dev-5511987654321"
    static let phone = "+5511987654321"

    /// The client `-uiSeed clientWithHealth` creates, so `-uiRoute health` can open her Health and consent screen.
    static let healthClientID = UUID(uuidString: "C0FFEE00-0000-4000-8000-000000000001") ?? UUID()

    /// A signed-in professional with her workspace set up, so a test can start on the locked screen or the app.
    /// `clientWithHealth` adds one client with nothing in her health record yet.
    @MainActor
    static func seedIfRequested(_ dependencies: AppDependencies, options: LaunchOptions) async {
        guard let seed = options.seed, ["onboarded", "clientWithHealth"].contains(seed), !options.keepsState else {
            return
        }
        let defaults = dependencies.defaults
        let user = AuthUser(id: userID, phoneE164: phone)
        defaults.set(try? JSONEncoder().encode(user), forKey: DefaultsKey.localDevUser)
        defaults.set(userID, forKey: DefaultsKey.setupCompletedUserID)

        guard let catalog = try? ProfessionCatalog.loadBundled(localization: .en),
              let preset = try? RegionCatalog.loadBundled().preset(for: "BR") else { return }
        var draft = OnboardingDraft(preset: preset, timeZoneID: "America/Sao_Paulo", localization: .en)
        draft.displayName = "Maria Silva"
        draft.professions = [.esthetician]
        draft.selectedServiceKeys = Set(OnboardingSuggestions.services(for: draft.professions, in: catalog)
            .filter(\.selected).map(\.key))
        draft.selectedTagKeys = Set(OnboardingSuggestions.tags(for: draft.professions, in: catalog)
            .filter(\.selected).map(\.key))
        let result = OnboardingBuilder.build(draft: draft, catalog: catalog, now: Date())
        try? dependencies.keyManager.prepare(createIfMissing: true)
        try? await dependencies.vault.repository?.saveOnboarding(result)
        if seed == "clientWithHealth" {
            let client = Client(id: healthClientID, name: "Ana Costa", createdAt: Date())
            _ = try? await dependencies.vault.repository?.save(client)
        }
    }
}
#endif
