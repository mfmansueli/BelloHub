//
//  ShareTexts.swift
//  BelloHub
//

import Foundation

/// The words she shares with her booking link: the line for an Instagram bio, the greeting for new WhatsApp chats,
/// the message that goes with the share sheet and what the printed table card says. Written in the business language,
/// because her clients read them, whatever language the app is in. Pure, so every localization is tested.
struct ShareTexts: Sendable {
    let localization: AppLocalization
    /// The professional's first name.
    let professionalName: String
    /// The link as people read it: `bellohub.app/maria`. Only for the bio line (Instagram never makes a bio link
    /// clickable; its own link field takes the full address from "Copy link").
    let displayLink: String
    /// The full address for a chat (`https://bellohub.app/maria`, `ClientLinkText`); empty until she saved one.
    var messageLink: String = ""

    /// "Book with me: bellohub.app/maria".
    var instagramBio: String {
        resolve(LocalizedStringResource("shareLink.instagram.text", defaultValue: "Book with me: \(isolatedLink)"))
    }

    /// "Hi! Thanks for your message. You can book with Maria here:" and the full link on its own line, so the chat
    /// makes it a link (`ClientLinkText`).
    var whatsAppGreeting: String {
        let link = messageLink.isEmpty ? displayLink : messageLink
        let sentence = resolve(LocalizedStringResource(
            "shareLink.whatsapp.text",
            defaultValue: "Hi! Thanks for your message. You can book with \(isolatedName) here: \(link)"
        ))
        return ClientLinkText.placeOnOwnLine(link, in: sentence)
    }

    /// "Book with Maria": the message of the share sheet.
    var shareMessage: String {
        resolve(LocalizedStringResource("shareLink.message", defaultValue: "Book with \(isolatedName)"))
    }

    /// "Scan to book with Maria": under the QR code.
    var qrCaption: String {
        resolve(LocalizedStringResource("shareLink.qr.caption", defaultValue: "Scan to book with \(isolatedName)"))
    }

    /// "Book with Maria": the title of the table card.
    var cardTitle: String {
        resolve(LocalizedStringResource("shareLink.card.title", defaultValue: "Book with \(isolatedName)"))
    }

    /// "Point your camera at the code".
    var cardSubtitle: String {
        resolve(LocalizedStringResource("shareLink.card.subtitle", defaultValue: "Point your camera at the code"))
    }

    // MARK: - Private

    /// The name and the link are isolated in Arabic so they cannot reorder the sentence around them.
    private var isolatedName: String {
        localization.isRightToLeft ? BidiIsolate.wrap(professionalName) : professionalName
    }

    private var isolatedLink: String {
        localization.isRightToLeft ? BidiIsolate.wrapLeftToRight(displayLink) : displayLink
    }

    private func resolve(_ resource: LocalizedStringResource) -> String {
        var localized = resource
        localized.locale = localization.locale
        return String(localized: localized)
    }
}
