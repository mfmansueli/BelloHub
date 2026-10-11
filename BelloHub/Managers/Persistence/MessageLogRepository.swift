//
//  MessageLogRepository.swift
//  BelloHub
//

import Foundation

/// The log of chats she opened with a message ready (D14: the app never sends by itself). Only the template kind is
/// kept, never the text. Composed into `ClientRecordRepository` like the other focused protocols.
protocol MessageLogRepository: Sendable {
    /// A client's entries, newest first.
    func messageLogs(for clientID: UUID) async throws -> [MessageLog]
    /// Every client's entries opened at or after `since`, newest first (the follow-up queue's "conversation opened").
    func messageLogs(since: Date) async throws -> [MessageLog]
    func save(_ log: MessageLog) async throws
}
