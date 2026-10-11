//
//  TagsRecordFixtures.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A finished setup for the tag and record-field tests, built the way onboarding builds it from the test catalog:
/// esthetician tags VIP and Sensitive Skin (positions 0 and 1), the fields `est.skin` (on) and `est.technique` (off),
/// and the intake items the catalog switches on. A namespace, so the names cannot clash with another suite's helpers.
enum TagsRecordFixtures {
    static func result(
        professions: [ProfessionID] = [.esthetician],
        tagKeys: Set<String> = ["est.vip", "est.sensitive"],
        term: ClientTerm = .client
    ) -> OnboardingResult {
        var draft = makeDraft(professions: professions)
        draft.selectedTagKeys = tagKeys
        draft.clientTerm = term
        return OnboardingBuilder.build(draft: draft, catalog: makeCatalog(), now: TestClock.now)
    }

    /// A tag at the end of the list.
    static func tag(_ name: String, color: String = "rose", position: Int = 9) -> Tag {
        Tag(id: UUID(), name: name, colorToken: color, position: position)
    }

    /// A client with these tags.
    static func client(_ name: String, tags: [Tag]) -> Client {
        Client(name: name, tagIDs: tags.map(\.id), createdAt: TestClock.now)
    }
}
