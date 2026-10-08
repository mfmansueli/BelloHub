//
//  ProfessionCatalog.swift
//  BelloHub
//

import Foundation

/// The professions and their suggested services, tags and record fields in one language
/// (`Resources/Professions/<localization>.json`, docs/07-LOCALIZATION.md section 5). Data, not code.
/// Pure: the bundle loader that finds the file is in `Managers/Locale/`.
struct ProfessionCatalog: Sendable, Equatable {
    enum LoadError: Error, Equatable {
        case malformed
        case empty
        case missingResource
    }

    let localization: String
    /// `needs_review` until a native reader signs the text off; information, not a gate (D41).
    let status: String
    let entries: [ProfessionEntry]

    func entry(for profession: ProfessionID) -> ProfessionEntry? {
        entries.first { $0.id == profession }
    }

    /// Entries in the order the onboarding grid shows them.
    var professions: [ProfessionID] { entries.map(\.id) }

    /// Decodes one catalog file. An entry whose id this version does not know is dropped rather than turned into
    /// `other`, so an old app never shows a newer profession twice.
    static func decode(_ data: Data) throws -> ProfessionCatalog {
        struct File: Decodable {
            let localization: String
            let status: String?
            let professions: [RawEntry]
        }
        struct RawEntry: Decodable {
            let id: String
            let name: String
            let plural: String
            let services: [SuggestedService]
            let tags: [SuggestedTag]
            let fields: [SuggestedField]
            let intake: [String]
        }
        let file: File
        do {
            file = try JSONDecoder().decode(File.self, from: data)
        } catch {
            throw LoadError.malformed
        }
        let entries: [ProfessionEntry] = file.professions.compactMap { raw in
            guard let id = ProfessionID(rawValue: raw.id) else { return nil }
            return ProfessionEntry(
                id: id, name: raw.name, plural: raw.plural, services: raw.services, tags: raw.tags,
                fields: raw.fields, intake: raw.intake.compactMap(IntakeItem.init(rawValue:))
            )
        }
        guard !entries.isEmpty else { throw LoadError.empty }
        return ProfessionCatalog(localization: file.localization, status: file.status ?? "needs_review",
                                 entries: entries)
    }
}
