//
//  ProfessionCatalogTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ProfessionCatalog")
struct ProfessionCatalogTests {
    @Test("A catalog decodes with its professions in file order")
    func decodes() {
        let catalog = makeCatalog()
        #expect(catalog.localization == "en")
        #expect(catalog.professions == [.esthetician, .hair, .other])
        #expect(catalog.entry(for: .esthetician)?.services.map(\.key) == ["est.glow", "est.peel", "shared.consult"])
        #expect(catalog.entry(for: .esthetician)?.intake == [.healthHistory, .consentForm])
        #expect(catalog.entry(for: .esthetician)?.services.first?.followUpWeeks == 4)
        #expect(catalog.entry(for: .esthetician)?.services[1].followUpWeeks == nil)
    }

    @Test("A profession this version does not know is dropped, not turned into Other")
    func unknownProfession() throws {
        let json = """
        {"localization": "en", "professions": [
          {"id": "astronaut", "name": "A", "plural": "a", "services": [], "tags": [], "fields": [], "intake": []},
          {"id": "other", "name": "Other", "plural": "professionals", "services": [], "tags": [], "fields": [],
           "intake": ["healthHistory", "teleport"]}]}
        """
        let catalog = try ProfessionCatalog.decode(Data(json.utf8))
        #expect(catalog.professions == [.other])
        // An unknown intake item is dropped too.
        #expect(catalog.entry(for: .other)?.intake == [.healthHistory])
        #expect(catalog.status == "needs_review")
    }

    @Test("Malformed and empty files are rejected with their own error")
    func rejects() {
        #expect(throws: ProfessionCatalog.LoadError.malformed) { try ProfessionCatalog.decode(Data("nope".utf8)) }
        #expect(throws: ProfessionCatalog.LoadError.empty) {
            try ProfessionCatalog.decode(Data(#"{"localization": "en", "professions": []}"#.utf8))
        }
    }

    // MARK: - The shipped files

    @Test("Every localization has a catalog that loads from the app bundle", arguments: AppLocalization.allCases)
    func bundled(localization: AppLocalization) throws {
        let catalog = try ProfessionCatalog.loadBundled(localization: localization)
        #expect(catalog.localization == localization.rawValue)
        #expect(catalog.professions.count == ProfessionID.allCases.count)
        for entry in catalog.entries {
            #expect(!entry.name.isEmpty && !entry.plural.isEmpty)
            #expect(entry.services.contains { $0.selected }, "\(entry.id) needs a preselected service")
            #expect(entry.fields.contains { $0.on }, "\(entry.id) needs a record field that starts on")
            #expect(entry.services.allSatisfy { $0.minutes > 0 && !$0.name.isEmpty })
        }
    }

    @Test("A translation never changes behavior: keys, minutes and defaults match English",
          arguments: AppLocalization.allCases)
    func sameStructureAsEnglish(localization: AppLocalization) throws {
        let english = try ProfessionCatalog.loadBundled(localization: .en)
        let other = try ProfessionCatalog.loadBundled(localization: localization)
        for (left, right) in zip(english.entries, other.entries) {
            #expect(left.id == right.id)
            #expect(left.services.map(\.key) == right.services.map(\.key))
            #expect(left.services.map(\.minutes) == right.services.map(\.minutes))
            #expect(left.services.map(\.followUpWeeks) == right.services.map(\.followUpWeeks))
            #expect(left.services.map(\.selected) == right.services.map(\.selected))
            #expect(left.tags.map(\.key) == right.tags.map(\.key))
            #expect(left.fields.map(\.on) == right.fields.map(\.on))
            #expect(left.intake == right.intake)
        }
    }
}
