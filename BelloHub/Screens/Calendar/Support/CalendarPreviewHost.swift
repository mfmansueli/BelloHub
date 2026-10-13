//
//  CalendarPreviewHost.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// What a calendar preview needs: the demo clients over an in-memory vault, her week (Monday to Friday, lunch, a
/// buffer) and the Services built over them. DEBUG only, like the in-memory vault it stands on.
@MainActor
struct CalendarPreviewWorld {
    let vault: VaultService
    let profile: ProfileService
    let registration: ClientRegistrationService
    let appointments: AppointmentService
    let timeBlocks: TimeBlockService
    let bookingSetup: BookingSetupService
    let clients: ClientsFixtures.Seeded
    /// A visit booked a few days from now.
    let upcomingVisitID: UUID

    static func make() async -> CalendarPreviewWorld? {
        guard let base = await ClientsPreviewWorld.make(), let repository = base.vault.repository else { return nil }
        let week = AvailabilitySettings(
            weekly: (2...6).map { AvailabilityRule(weekday: $0, startMinutes: 9 * 60, endMinutes: 18 * 60) },
            breaks: [BreakRule(weekday: nil, startMinutes: 12 * 60 + 30, endMinutes: 13 * 60 + 30, label: "Lunch")],
            daysOff: [], bufferMinutes: 15, minNoticeHours: 2, maxDaysAhead: 60, timeZoneID: "America/Sao_Paulo"
        )
        try? await repository.save(week)
        let upcoming = (try? await repository.appointments(for: base.seeded.helena))?.first { $0.status.holdsTime }
        return CalendarPreviewWorld(
            vault: base.vault, profile: base.profile, registration: base.registration,
            appointments: AppointmentService(vault: base.vault), timeBlocks: TimeBlockService(vault: base.vault),
            bookingSetup: BookingSetupService(vault: base.vault), clients: base.seeded,
            upcomingVisitID: upcoming?.id ?? UUID()
        )
    }
}

/// Builds the preview world once and puts every Service the calendar screens read in the environment.
struct CalendarPreviewHost<Content: View>: View {
    @State private var world: CalendarPreviewWorld?
    let content: (CalendarPreviewWorld) -> Content

    init(@ViewBuilder content: @escaping (CalendarPreviewWorld) -> Content) {
        self.content = content
    }

    var body: some View {
        Group {
            if let world {
                content(world)
                    .environment(world.vault)
                    .environment(world.profile)
                    .environment(world.registration)
                    .environment(world.appointments)
                    .environment(world.timeBlocks)
                    .environment(world.bookingSetup)
                    .environment(MessageService(vault: world.vault))
            } else {
                ProgressView()
            }
        }
        .task { world = await CalendarPreviewWorld.make() }
    }
}
#endif
