//
//  HealthQuestion.swift
//  BelloHub
//

/// One question of the health form, in one language. The `key` never changes between languages or versions, so an
/// answer saved today still maps to its question after the wording is edited.
struct HealthQuestion: Identifiable, Hashable, Sendable {
    let key: String
    /// The short label of the answer in the professional's list: "Allergies".
    let name: String
    /// The sentence the client reads: "Any allergies?".
    let prompt: String
    let kind: HealthQuestionKind
    /// The choices of a `choices` question, without "None" (see `allowsNone`).
    let options: [HealthOption]
    /// A `choices` question that also offers "None" (exclusive with the other choices).
    let allowsNone: Bool
    /// The professions the question is offered to. Empty means every profession.
    let professions: [ProfessionID]
    /// Whether the question starts switched on for a profession it applies to.
    let isOnByDefault: Bool

    var id: String { key }

    /// The name of one choice, or nil for a key this version does not know.
    func optionName(for optionKey: String) -> String? {
        options.first { $0.key == optionKey }?.name
    }
}
