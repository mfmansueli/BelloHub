//
//  IntakePayload.swift
//  BelloHub
//

import Foundation

/// The plaintext of an `intake` envelope (docs/06-PRIVACY-SECURITY.md section 3.4), schema 2 (D55) or the older
/// schema 1 (a browser may have sealed one before the change: it still opens; its consent block and signature are
/// ignored, consents are the professional's own business). Answers are typed by the browser: a boolean is yes/no, a
/// string is text, a list is choices.
struct IntakePayload: Equatable, Sendable {
    let schema: Int
    let bookingId: String
    let localeId: String?
    /// The template version the client answered; nil when the page sent something that is not a number.
    let formVersion: Int?
    let answers: [String: HealthAnswer]
    let isForMinor: Bool
    let minorName: String?
    /// Schema 1 only.
    let clientName: String?
    let submittedAt: Date?

    /// Reads schema 1 and 2. Throws `DecodingError` when the JSON is not an intake payload.
    static func decode(_ data: Data) throws -> IntakePayload {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not an object"))
        }
        guard let schema = object["schema"] as? Int, (1...2).contains(schema),
              let bookingId = object["bookingId"] as? String, !bookingId.isEmpty,
              let rawAnswers = object["answers"] as? [String: Any]
        else { throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not an intake payload")) }
        var answers: [String: HealthAnswer] = [:]
        for (key, value) in rawAnswers {
            guard let answer = HealthAnswer(payloadValue: value) else {
                throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "answer \(key)"))
            }
            answers[key] = answer
        }
        let version = object["formVersion"]
        let formVersion = (version as? Int) ?? (version as? String).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        return IntakePayload(
            schema: schema,
            bookingId: bookingId,
            localeId: object["localeId"] as? String,
            formVersion: formVersion,
            answers: answers,
            isForMinor: object["isForMinor"] as? Bool ?? false,
            minorName: (object["minorName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            clientName: (object["clientName"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            submittedAt: (object["submittedAt"] as? String).flatMap(Self.instant)
        )
    }

    /// ISO-8601 with or without fractions (the browser writes `toISOString()`).
    private static func instant(_ text: String) -> Date? {
        if let date = try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        return try? Date(text, strategy: Date.ISO8601FormatStyle())
    }
}

extension HealthAnswer {
    /// The browser's answer types (`boolean | string | string[]`), nothing else.
    init?(payloadValue: Any) {
        if let flag = payloadValue as? Bool {
            self = flag ? .yes : .no
        } else if let text = payloadValue as? String {
            self = .text(text)
        } else if let list = payloadValue as? [Any] {
            let strings = list.compactMap { $0 as? String }
            guard strings.count == list.count else { return nil }
            self = .choices(strings)
        } else {
            return nil
        }
    }
}
