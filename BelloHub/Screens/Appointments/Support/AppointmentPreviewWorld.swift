//
//  AppointmentPreviewWorld.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What a visit-screen preview needs: an in-memory vault with a professional and the demo calendar
/// (`AppointmentFixtures`), and the Services built over it. A message that would open WhatsApp is only recorded.
@MainActor
struct AppointmentPreviewWorld {
    let vault: VaultService
    let profile: ProfileService
    let appointments: AppointmentService
    let setup: BookingSetupService
    let messages: MessageService
    let client: UUID
    let upcoming: UUID
    let missed: UUID

    static func make() async -> AppointmentPreviewWorld? {
        let repository: any ClientRecordRepository = InMemoryClientRecordRepository()
        let vault = VaultService(repository: repository)
        let profile = ProfileService(vault: vault)
        let now = Date()
        let professional = ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: "America/Sao_Paulo", currencyCode: "BRL",
            appLocaleID: "en", professions: [.esthetician], createdAt: now
        )
        do {
            try await repository.save(professional)
            let seeded = try await AppointmentFixtures.seed(into: repository, now: now)
            await profile.load()
            return AppointmentPreviewWorld(
                vault: vault, profile: profile, appointments: AppointmentService(vault: vault),
                setup: BookingSetupService(vault: vault),
                messages: MessageService(repository: repository, sender: PreviewMessageSender()),
                client: seeded.ana, upcoming: seeded.upcoming, missed: seeded.missed
            )
        } catch {
            return nil
        }
    }
}

/// Opens nothing: a preview must not leave the app.
@MainActor
private final class PreviewMessageSender: MessageSending {
    func openInApp(_ url: URL) async -> Bool { true }
}
#endif
