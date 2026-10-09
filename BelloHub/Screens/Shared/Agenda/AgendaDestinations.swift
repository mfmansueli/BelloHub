//
//  AgendaDestinations.swift
//  BelloHub
//

import SwiftUI

extension View {
    /// Maps every `AgendaRoute` to its screen. Put it on the root of a tab's `NavigationStack`.
    func agendaDestinations() -> some View {
        navigationDestination(for: AgendaRoute.self) { route in
            switch route {
            case .appointment(let id): AppointmentView(appointmentID: id)
            case .weekGlance: WeekGlanceView()
            case .followUps: FollowUpsView()
            case .winBack: WinBackView()
            case .sessionPlan(let clientID): SessionPlanView(clientID: clientID)
            case .noShowHistory(let clientID): NoShowHistoryView(clientID: clientID)
            case .bookingRequest(let id): BookingRequestView(bookingID: id)
            case .rescheduleRequest(let id): RescheduleRequestView(requestID: id)
            case .waitlist: WaitlistView()
            }
        }
    }

    /// Presents the sheet an `AgendaSheet` names.
    func agendaSheet(item: Binding<AgendaSheet?>) -> some View {
        sheet(item: item) { sheet in
            switch sheet {
            case .newAppointment(let clientID, let startsAt): NewAppointmentView(clientID: clientID, startsAt: startsAt)
            case .reschedule(let id): RescheduleView(appointmentID: id)
            case .cancel(let id): CancelAppointmentView(appointmentID: id)
            case .message(let id): MessageClientView(appointmentID: id)
            case .noShowMark(let id): NoShowMarkView(appointmentID: id)
            case .beforeYouStart(let id): BeforeYouStartView(appointmentID: id)
            case .runningLate(let id): RunningLateView(appointmentID: id)
            case .blockTime(let day): BlockTimeView(day: day)
            case .clientMessage(let request): ClientMessageView(request: request)
            }
        }
    }
}
