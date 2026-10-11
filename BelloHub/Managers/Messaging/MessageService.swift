//
//  MessageService.swift
//  BelloHub
//

import Foundation
import Observation

/// Gets a ready message in front of a client and remembers that she opened the chat. Every "send a message" action of
/// the app goes through it (the visit, the no-show note, running late, win-back): it walks the `MessageDispatchPlan`
/// (WhatsApp, then Messages, then the share sheet) and writes one `MessageLog` entry for the channel that opened.
///
/// The app never sends by itself (D14), so the entry says "she was about to send", never "it was sent". The log keeps
/// the template kind and the time, never the text, and the callers never put clinical data in a message.
@MainActor
@Observable
final class MessageService {
    /// What happened to a request, for the screen to say.
    enum Outcome: Equatable, Sendable {
        /// The chat of this channel is open with the text ready.
        case opened(MessageChannel)
        /// Neither WhatsApp nor Messages could open: the screen shows the system share sheet with this text.
        case needsShareSheet(text: String)
    }

    /// When she last opened a chat for each client during this session, so a list (follow-ups, win back) can mark the
    /// ones she already wrote to. In memory only: the persisted trace is the `MessageLog` entry.
    private(set) var recentlyOpened: [UUID: Date] = [:]

    /// Looked up on each use, because the vault may be unavailable (nil) when the store could not be opened.
    private let source: @MainActor () -> (any MessageLogRepository)?
    private let sender: any MessageSending

    init(vault: VaultService, sender: any MessageSending = SystemMessageSender()) {
        source = { vault.repository }
        self.sender = sender
    }

    init(repository: any MessageLogRepository, sender: any MessageSending) {
        source = { repository }
        self.sender = sender
    }

    /// Opens the best chat available with `text` ready and logs it. `template` is the kind (`cancelled`, `noShow`,
    /// `late`, or a quick reply's key), never the text. A failed log write does not stop the message: the log is a
    /// convenience, the message is the point. Without a client (a person on the waitlist who is not one of hers yet)
    /// nothing is logged.
    @discardableResult
    func send(
        text: String, to clientID: UUID?, phoneE164: String?, template: String,
        preferred: MessagingChannel = .whatsapp, now: Date = Date()
    ) async -> Outcome {
        let plan = MessageDispatchPlan.make(phoneE164: phoneE164, text: text, preferred: preferred)
        for attempt in plan.attempts {
            switch attempt {
            case .whatsApp(let url), .sms(let url):
                guard await sender.openInApp(url) else { continue }
                guard let clientID else { return .opened(attempt.channel) }
                await log(clientID: clientID, channel: attempt.channel, template: template, now: now)
                recentlyOpened[clientID] = now
                return .opened(attempt.channel)
            case .share:
                if let clientID { await log(clientID: clientID, channel: .share, template: template, now: now) }
                return .needsShareSheet(text: text)
            }
        }
        return .needsShareSheet(text: text)
    }

    // MARK: - Private

    private func log(clientID: UUID, channel: MessageChannel, template: String, now: Date) async {
        guard let repository = source() else { return }
        let entry = MessageLog(id: UUID(), clientID: clientID, channel: channel, template: template, openedAt: now)
        try? await repository.save(entry)
    }
}
