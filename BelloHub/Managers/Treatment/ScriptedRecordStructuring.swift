//
//  ScriptedRecordStructuring.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// `-uiVoice scripted`: structuring that answers with a fixed draft after a short wait, so a UI test sees the
/// organizing screen and then the review. It fills only the fields it finds in `fields`, picked by the last part of
/// the key. DEBUG only; it never ships.
struct ScriptedRecordStructuring: RecordStructuring {
    var delay: Duration = .milliseconds(700)

    func isAvailable(for locale: Locale) async -> Bool { true }

    func structure(
        transcript: String, fields: [StructuringField], locale: Locale
    ) async throws -> StructuredRecordDraft {
        try await Task.sleep(for: delay)
        let answers = [
            "notes": "Skin a little sensitive around the cheeks.",
            "technique": "Reduced intensity on the cheeks.",
            "products": "Calming serum",
            "result": "Responded well.",
            "nextSession": "Return in about 4 weeks."
        ]
        var values: [String: String] = [:]
        for field in fields {
            let suffix = field.key.split(separator: ".").last.map(String.init) ?? field.key
            if let answer = answers[suffix] { values[field.key] = answer }
        }
        return StructuredRecordDraft(values: values, summary: nil)
    }
}
#endif
