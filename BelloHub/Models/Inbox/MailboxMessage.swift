//
//  MailboxMessage.swift
//  BelloHub
//

import Foundation

/// A sealed item that is not a health form, opened on the phone: a check-in after a visit or a copy/deletion request
/// (docs/06-PRIVACY-SECURITY.md section 3.4). It is shown in the inbox until she marks it handled; only then is it
/// acknowledged (deleted) on the server. It lives in memory, never in `UserDefaults`: a check-in may carry a photo.
struct MailboxMessage: Identifiable, Equatable, Sendable {
    enum Content: Equatable, Sendable {
        /// `good`, `okay`, `irritated` or `reaction`, with her note; the photo is JPEG bytes.
        case checkin(feeling: String, note: String?, photo: Data?)
        /// `copy` or `delete`, with the name and phone she typed.
        case dataRequest(request: String, name: String, phone: String, note: String?)
    }

    let id: String
    let bookingId: String
    let content: Content
    let receivedAt: Date
    let submittedAt: Date?

    /// Reads a `checkin` or `datarequest` plaintext. Nil when the JSON is not one of them.
    static func decode(_ data: Data, kind: MailboxKind, id: String, bookingId: String, receivedAt: Date) -> MailboxMessage? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let submitted = (object["submittedAt"] as? String).flatMap { try? Date($0, strategy: .iso8601) }
        switch kind {
        case .checkin:
            guard let feeling = object["feeling"] as? String else { return nil }
            let photo = (object["photoJpeg"] as? String).flatMap { Data(base64Encoded: $0) }
            return MailboxMessage(
                id: id, bookingId: bookingId,
                content: .checkin(feeling: feeling, note: object["note"] as? String, photo: photo),
                receivedAt: receivedAt, submittedAt: submitted
            )
        case .datarequest:
            guard let request = object["request"] as? String else { return nil }
            return MailboxMessage(
                id: id, bookingId: bookingId,
                content: .dataRequest(
                    request: request, name: object["name"] as? String ?? "", phone: object["phone"] as? String ?? "",
                    note: object["note"] as? String
                ),
                receivedAt: receivedAt, submittedAt: submitted
            )
        case .intake:
            return nil
        }
    }
}
