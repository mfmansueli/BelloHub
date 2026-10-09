//
//  MessageSuggestion.swift
//  BelloHub
//

import Foundation

/// Which of her quick replies fits a visit best, so the message sheet opens with the likely one chosen (3.6). She can
/// pick another; this only saves a tap. Pure.
enum MessageSuggestion {
    static func builtIn(for appointment: Appointment, now: Date) -> BuiltInQuickReply {
        switch appointment.status {
        case .booked, .confirmed:
            // Before the visit: confirm it. Once the time has passed and she has not closed it, check in.
            appointment.endsAt <= now ? .checkIn : .confirm
        case .completed: .aftercare
        case .cancelled: .reschedule
        case .noShow: .comeBack
        }
    }

    /// Her stored reply for that built-in message, or her first reply when she deleted... (built-in ones cannot be
    /// deleted, so the fallback only covers a list that has not loaded).
    static func reply(for appointment: Appointment, among replies: [QuickReply], now: Date) -> QuickReply? {
        let wanted = builtIn(for: appointment, now: now).rawValue
        return replies.first { $0.builtInKey == wanted } ?? replies.first
    }
}
