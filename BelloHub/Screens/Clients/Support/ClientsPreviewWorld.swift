//
//  ClientsPreviewWorld.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What a Clients preview needs: an in-memory vault with a professional, the demo clients and the Services built over
/// them. DEBUG only, like the in-memory vault it stands on.
@MainActor
struct ClientsPreviewWorld {
    let vault: VaultService
    let profile: ProfileService
    let registration: ClientRegistrationService
    let regions: RegionCatalog
    let seeded: ClientsFixtures.Seeded

    static func make() async -> ClientsPreviewWorld? {
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository()
        let vault = VaultService(repository: repository)
        let profile = ProfileService(vault: vault)
        let now = Date()
        let professional = ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: "America/Sao_Paulo", currencyCode: "BRL",
            appLocaleID: "en", professions: [.esthetician], createdAt: now
        )
        let tags = ["Sensitive Skin", "VIP", "Bridal", "Regular"].enumerated().map { index, name in
            Tag(id: UUID(), name: name, colorToken: ClientFormRules.tagColorToken(forPosition: index), position: index)
        }
        do {
            try await repository.save(professional)
            for tag in tags { try await repository.save(tag) }
            let seeded = try await ClientsFixtures.seed(into: repository, now: now)
            await profile.load()
            return ClientsPreviewWorld(
                vault: vault, profile: profile, registration: ClientRegistrationService(vault: vault),
                regions: (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: []), seeded: seeded
            )
        } catch {
            return nil
        }
    }
}
#endif
