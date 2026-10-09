//
//  AgendaSheet.swift
//  BelloHub
//

import Foundation

/// The agenda's secondary flows, presented as sheets (CLAUDE.md: secondary flows are sheets). A screen sets an
/// `AgendaSheet?` state and adds `.agendaSheet(item:)`.
enum AgendaSheet: Hashable, Identifiable, Sendable {
    /// 3.1 NewAppointment, for a client and a time when the caller knows them.
    case newAppointment(clientID: UUID?, startsAt: Date?)
    /// 3.4 Reschedule.
    case reschedule(appointmentID: UUID)
    /// 3.5 CancelAppointment.
    case cancel(appointmentID: UUID)
    /// 3.6 MessageClient.
    case message(appointmentID: UUID)
    /// 3.7 NoShowMark.
    case noShowMark(appointmentID: UUID)
    /// 3.3 BeforeYouStart.
    case beforeYouStart(appointmentID: UUID)
    /// 2.12 RunningLate.
    case runningLate(appointmentID: UUID)
    /// 6.6 BlockTime.
    case blockTime(day: Date?)

    var id: Self { self }
}
