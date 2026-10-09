//
//  ImmediateNotifying.swift
//  BelloHub
//

/// Posts one local notification now (the app raises its own alert after a silent push brought a sealed form, docs/06
/// section 3.5). The text is generic by construction: the caller passes a kind and a localized title and body with no
/// name in them. Behind a protocol so the mailbox is tested without the notification center.
protocol ImmediateNotifying: Sendable {
    func post(id: String, threadID: String, title: String, body: String) async
}
