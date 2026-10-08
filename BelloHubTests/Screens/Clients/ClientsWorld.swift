//
//  ClientsWorld.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// An in-memory vault with a signed-in professional (Brazil, São Paulo) and the tags she chose: what the Clients
/// ViewModels need. Every ViewModel test builds one, so nothing is shared between tests.
@MainActor
struct ClientsWorld {
    let repository: InMemoryClientRecordRepository
    let vault: VaultService
    let profile: ProfileService
    let tags: [Tag]
    let regions: RegionCatalog

    static func make(
        tagNames: [String] = ["Sensitive Skin", "VIP", "Bridal"], clientTerm: ClientTerm = .client,
        regionCode: String = "BR"
    ) async throws -> ClientsWorld {
        let repository = InMemoryClientRecordRepository(clock: { TestClock.now })
        let vault = VaultService(repository: repository)
        let profile = ProfileService(vault: vault)
        var professional = ProfessionalProfile(
            displayName: "Maria Silva", regionCode: regionCode, timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "en", professions: [.esthetician], clientTerm: clientTerm,
            createdAt: TestClock.now
        )
        professional.appLocaleID = "en"
        try await repository.save(professional)
        let tags = tagNames.enumerated().map { index, name in
            Tag(id: UUID(), name: name, colorToken: ClientFormRules.tagColorToken(forPosition: index), position: index)
        }
        for tag in tags { try await repository.save(tag) }
        await profile.load()
        return ClientsWorld(
            repository: repository, vault: vault, profile: profile, tags: tags,
            regions: try RegionCatalog.loadBundled()
        )
    }

    /// A vault that cannot be opened (the store failed), for the error states.
    static func unavailable() -> (vault: VaultService, profile: ProfileService) {
        let vault = VaultService(repository: nil)
        return (vault, ProfileService(vault: vault))
    }
}

/// A client with the fields the list and the form look at.
func makeListedClient(
    id: UUID = UUID(), name: String = "Ana Costa", phone: String? = nil, tagIDs: [UUID] = [],
    isArchived: Bool = false, email: String? = nil, importantNote: String? = nil
) -> Client {
    Client(
        id: id, name: name, phoneE164: phone, email: email, tagIDs: tagIDs, isArchived: isArchived,
        createdAt: TestClock.days(-200), importantNote: importantNote
    )
}
