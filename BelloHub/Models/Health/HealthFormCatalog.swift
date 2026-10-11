//
//  HealthFormCatalog.swift
//  BelloHub
//

import Foundation

/// Every question the health form can ask, in one language (`Resources/HealthForms/healthform-<localization>.json`,
/// docs/05-DATA-MODEL.md). Data, not code: which questions a profession is offered, their order and their wording
/// all live in the files, with the same keys in every language (`scripts/check-health-forms.sh`).
/// Pure: the bundle loader that finds the file is in `Managers/Forms/`.
struct HealthFormCatalog: Sendable, Equatable {
    enum LoadError: Error, Equatable {
        case malformed
        case empty
        case missingResource
    }

    let localization: String
    /// `needs_review` until a native reader signs the text off; information, not a gate (D41).
    let status: String
    /// In the order the form asks them.
    let questions: [HealthQuestion]

    func question(for key: String) -> HealthQuestion? {
        questions.first { $0.key == key }
    }

    /// Decodes one catalog file. A question whose kind this version does not know is dropped rather than guessed, so
    /// an old app never asks something it cannot read back.
    static func decode(_ data: Data) throws -> HealthFormCatalog {
        struct File: Decodable {
            let localization: String
            let status: String?
            let questions: [RawQuestion]
        }
        struct RawOption: Decodable {
            let key: String
            let name: String
        }
        struct RawQuestion: Decodable {
            let key: String
            let name: String
            let prompt: String
            let kind: String
            let options: [RawOption]?
            let allowsNone: Bool?
            let professions: [String]?
            let isOnByDefault: Bool?
        }
        let file: File
        do {
            file = try JSONDecoder().decode(File.self, from: data)
        } catch {
            throw LoadError.malformed
        }
        let questions: [HealthQuestion] = file.questions.compactMap { raw in
            guard let kind = HealthQuestionKind(rawValue: raw.kind) else { return nil }
            return HealthQuestion(
                key: raw.key, name: raw.name, prompt: raw.prompt, kind: kind,
                options: (raw.options ?? []).map { HealthOption(key: $0.key, name: $0.name) },
                allowsNone: raw.allowsNone ?? false,
                professions: (raw.professions ?? []).compactMap(ProfessionID.init(rawValue:)),
                isOnByDefault: raw.isOnByDefault ?? true
            )
        }
        guard !questions.isEmpty else { throw LoadError.empty }
        return HealthFormCatalog(
            localization: file.localization, status: file.status ?? "needs_review", questions: questions
        )
    }
}
