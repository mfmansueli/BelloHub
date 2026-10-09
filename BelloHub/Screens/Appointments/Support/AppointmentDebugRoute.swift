//
//  AppointmentDebugRoute.swift
//  BelloHub
//

#if DEBUG
import SwiftUI

/// `-uiRoute appointments`: lists the two seeded visits and opens them through the real route (`AgendaRoute`), so a UI
/// test can drive the visit screens before the Calendar tab, which the calendar slice builds, can open them. DEBUG
/// only; it never ships.
struct AppointmentDebugRoute: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink(value: AgendaRoute.appointment(id: AppointmentFixtures.seeded.upcoming)) {
                    Text(verbatim: "Ana Costa")
                }
                .accessibilityIdentifier("debugAppointments.upcoming")
                NavigationLink(value: AgendaRoute.appointment(id: AppointmentFixtures.seeded.missed)) {
                    Text(verbatim: "Beatriz Lima")
                }
                .accessibilityIdentifier("debugAppointments.missed")
            }
            .navigationTitle(Text(verbatim: "Appointments"))
            .agendaDestinations()
        }
    }
}
#endif
