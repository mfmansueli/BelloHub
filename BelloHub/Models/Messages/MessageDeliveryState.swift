//
//  MessageDeliveryState.swift
//  BelloHub
//

import Foundation

/// Where a message to a client stands, as far as the app can honestly know (routine-a item 6). The app only opens
/// WhatsApp (or Messages) with the text ready (D14), so it can know that the chat was opened, never that the message
/// was sent or delivered; "marked as sent" is her own statement and is always shown as hers.
enum MessageDeliveryState: Equatable, Sendable {
    /// Nothing opened yet.
    case readyToSend
    /// The chat was opened with the text ready. Not a proof of sending.
    case conversationOpened(at: Date)
    /// She said she sent it.
    case markedSentByHer(at: Date)

    /// A visit reminder: `reminderMarkedSentAt` wins, then `reminderSentAt` (the chat was opened).
    static func reminder(of appointment: Appointment) -> MessageDeliveryState {
        if let marked = appointment.reminderMarkedSentAt { return .markedSentByHer(at: marked) }
        if let opened = appointment.reminderSentAt { return .conversationOpened(at: opened) }
        return .readyToSend
    }

    /// Any other message: her mark wins, then the newest chat opened for the client since `since`.
    static func make(openedAt: Date?, markedSentAt: Date?) -> MessageDeliveryState {
        if let markedSentAt { return .markedSentByHer(at: markedSentAt) }
        if let openedAt { return .conversationOpened(at: openedAt) }
        return .readyToSend
    }

    var isOpened: Bool {
        if case .conversationOpened = self { true } else { false }
    }

    var isMarkedSent: Bool {
        if case .markedSentByHer = self { true } else { false }
    }
}
