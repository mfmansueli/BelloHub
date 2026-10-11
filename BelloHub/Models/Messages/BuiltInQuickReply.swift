//
//  BuiltInQuickReply.swift
//  BelloHub
//

import Foundation

/// The six messages every professional starts with (the prototype's list). They are written in her business language
/// when she first opens the screen and are hers to edit from then on; the originals stay in the catalog so she can put
/// one back.
enum BuiltInQuickReply: String, CaseIterable, Sendable {
    case confirm
    case late
    case reschedule
    case aftercare
    case checkIn
    case comeBack

    /// A fixed id per message, so two devices that both create the defaults agree on them instead of doubling the list.
    var id: UUID {
        let suffix = Self.allCases.firstIndex(of: self) ?? 0
        return UUID(uuidString: "B3110000-0000-4000-8000-00000000010\(suffix)") ?? UUID()
    }

    /// The position the message starts at.
    var position: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    func title(in localization: AppLocalization) -> String {
        resolve(titleResource, in: localization)
    }

    func text(in localization: AppLocalization) -> String {
        resolve(textResource, in: localization)
    }

    /// The message as a stored reply, in `localization`.
    func reply(in localization: AppLocalization, now: Date) -> QuickReply {
        QuickReply(
            id: id, builtInKey: rawValue, title: title(in: localization), text: text(in: localization),
            position: position, updatedAt: now
        )
    }

    // MARK: - Catalog keys

    private var titleResource: LocalizedStringResource {
        switch self {
        case .confirm:
            LocalizedStringResource("quickReplies.default.confirm.title", defaultValue: "Confirm appointment")
        case .late: LocalizedStringResource("quickReplies.default.late.title", defaultValue: "Running late")
        case .reschedule: LocalizedStringResource("quickReplies.default.reschedule.title", defaultValue: "Reschedule")
        case .aftercare: LocalizedStringResource("quickReplies.default.aftercare.title", defaultValue: "Aftercare")
        case .checkIn: LocalizedStringResource("quickReplies.default.checkIn.title", defaultValue: "Check-in")
        case .comeBack: LocalizedStringResource("quickReplies.default.comeBack.title", defaultValue: "Come back soon")
        }
    }

    private var textResource: LocalizedStringResource {
        switch self {
        case .confirm:
            LocalizedStringResource("quickReplies.default.confirm.text", defaultValue: """
                Hi {name}! Confirming your {service} on {date} at {time}.
                {address}
                Reply YES to confirm. To change or cancel:
                {link}
                """)
        case .late:
            LocalizedStringResource("quickReplies.default.late.text", defaultValue: """
                Hi {name}, I am running about 10 minutes behind. Thank you for your patience!
                """)
        case .reschedule:
            LocalizedStringResource("quickReplies.default.reschedule.text", defaultValue: """
                Hi {name}, I need to move your {service}.
                {address}
                Please choose a new time here:
                {link}
                """)
        case .aftercare:
            LocalizedStringResource("quickReplies.default.aftercare.text", defaultValue: """
                Hi {name}! After your {service}: keep the area clean, avoid heat and direct sun today, \
                and message me if anything feels off.
                """)
        case .checkIn:
            LocalizedStringResource("quickReplies.default.checkIn.text", defaultValue: """
                Hi {name}, how are you feeling after your {service}? Tell me in one tap: {link}
                """)
        case .comeBack:
            LocalizedStringResource("quickReplies.default.comeBack.text", defaultValue: """
                Hi {name}! It has been a while since your {service}. I have a few openings this month. \
                Want me to save a time? {link}
                """)
        }
    }

    /// The wording this message had before the 2026-10-11 rewrite (the link glued inside a sentence, no `{address}`),
    /// or nil for a message that did not change. Used only to upgrade a reply she never edited
    /// (`QuickReplyUpgrade`).
    func previousText(in localization: AppLocalization) -> String? {
        switch self {
        case .confirm:
            resolve(LocalizedStringResource("quickReplies.default.confirm.text.v1", defaultValue: """
                Hi {name}! Confirming your {service} on {date} at {time}. \
                Reply YES to confirm or use {link} to change it.
                """), in: localization)
        case .reschedule:
            resolve(LocalizedStringResource("quickReplies.default.reschedule.text.v1", defaultValue: """
                Hi {name}, I need to move your {service}. Here are new times: {link}
                """), in: localization)
        case .late, .aftercare, .checkIn, .comeBack:
            nil
        }
    }

    private func resolve(_ resource: LocalizedStringResource, in localization: AppLocalization) -> String {
        var localized = resource
        localized.locale = localization.locale
        return String(localized: localized)
    }
}
