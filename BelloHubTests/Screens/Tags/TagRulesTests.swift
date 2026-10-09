//
//  TagRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("TagRules")
struct TagRulesTests {
    /// `BelloHub.Tag`, because Swift Testing has a `Tag` of its own.
    private func makeTag(
        _ name: String, color: String = "rose", position: Int = 0, id: UUID = UUID()
    ) -> BelloHub.Tag {
        BelloHub.Tag(id: id, name: name, colorToken: color, position: position)
    }

    // MARK: - Names

    @Test("An empty name, or one of only spaces, is empty")
    func emptyNames() {
        #expect(TagRules.check("", among: []) == .empty)
        #expect(TagRules.check("  \n ", among: []) == .empty)
    }

    @Test("A name is stored with its whitespace collapsed")
    func cleansWhitespace() {
        #expect(TagRules.check("  Sensitive   skin ", among: []) == .accepted("Sensitive skin"))
    }

    @Test("Thirty characters are fine and thirty-one are too long")
    func lengthLimit() {
        let thirty = String(repeating: "a", count: 30)
        #expect(TagRules.maximumNameLength == 30)
        #expect(TagRules.check(thirty, among: []) == .accepted(thirty))
        #expect(TagRules.check(thirty + "a", among: []) == .tooLong)
    }

    @Test("Names are unique ignoring case and accents")
    func duplicates() {
        let existing = [makeTag("Pele sensível")]
        #expect(TagRules.check("pele SENSIVEL", among: existing) == .duplicate)
        #expect(TagRules.check("Pele sensível", among: existing) == .duplicate)
        #expect(TagRules.check("Pele seca", among: existing) == .accepted("Pele seca"))
    }

    @Test("A tag being renamed may keep its own name in another case, but not take another tag's")
    func renaming() {
        let vip = makeTag("vip")
        let bridal = makeTag("Bridal")
        #expect(TagRules.check("VIP", among: [vip, bridal], editing: vip.id) == .accepted("VIP"))
        #expect(TagRules.check("bridal", among: [vip, bridal], editing: vip.id) == .duplicate)
    }

    @Test("The length rule is checked before the duplicate rule")
    func lengthBeforeDuplicate() {
        let long = String(repeating: "x", count: 31)
        #expect(TagRules.check(long, among: [makeTag(long)]) == .tooLong)
    }

    // MARK: - New and updated tags

    @Test("A new tag goes after the last one, with a cleaned name and the id it was given")
    func newTag() throws {
        let id = UUID()
        let existing = [makeTag("VIP", position: 0), makeTag("Bridal", position: 4)]

        let tag = try #require(TagRules.makeTag(name: "  Regular ", color: .sage, among: existing, makeID: { id }))

        #expect(tag == BelloHub.Tag(id: id, name: "Regular", colorToken: "sage", position: 5))
        #expect(TagRules.makeTag(name: "vip", color: .sage, among: existing) == nil)
        #expect(TagRules.makeTag(name: "", color: .sage, among: existing) == nil)
    }

    @Test("The first tag is numbered zero")
    func firstTagPosition() throws {
        let tag = try #require(TagRules.makeTag(name: "VIP", color: .rose, among: []))
        #expect(tag.position == 0)
    }

    @Test("Updating renames and recolors but keeps the id and the position")
    func updating() throws {
        let vip = makeTag("VIP", color: "rose", position: 2)

        let updated = try #require(TagRules.updating(vip, name: " Very  important ", color: .peach, among: [vip]))

        #expect(updated.id == vip.id && updated.position == 2)
        #expect(updated.name == "Very important" && updated.colorToken == "peach")
        #expect(TagRules.updating(vip, name: "", color: .peach, among: [vip]) == nil)
    }

    // MARK: - Color

    @Test("A new tag starts with the color the fewest tags use")
    func suggestedColor() {
        #expect(TagRules.suggestedColor(among: []) == .rose)
        let used = [makeTag("a", color: "rose"), makeTag("b", color: "rose"), makeTag("c", color: "sage")]
        #expect(TagRules.suggestedColor(among: used) == .peach)
        let all = used + [makeTag("d", color: "peach"), makeTag("e", color: "sand")]
        #expect(TagRules.suggestedColor(among: all) == .sage)
    }

    @Test("A token this version does not know counts as sand")
    func unknownColorCountsAsSand() {
        let tags = [makeTag("a", color: "rose"), makeTag("b", color: "sage"), makeTag("c", color: "peach"),
                    makeTag("d", color: "mauve")]
        // sand is used once (the unknown token), the others once: the first color, rose, wins the tie.
        #expect(TagRules.suggestedColor(among: tags) == .rose)
        #expect(TagRules.suggestedColor(among: Array(tags.dropLast())) == .sand)
    }

    // MARK: - Order

    @Test("A drag renumbers the whole list from zero")
    func moving() {
        let tags = [makeTag("A", position: 0), makeTag("B", position: 1), makeTag("C", position: 2)]

        let toEnd = TagRules.moving(tags, from: [0], to: 3)
        #expect(toEnd.map(\.name) == ["B", "C", "A"] && toEnd.map(\.position) == [0, 1, 2])

        let toFront = TagRules.moving(tags, from: [2], to: 0)
        #expect(toFront.map(\.name) == ["C", "A", "B"] && toFront.map(\.position) == [0, 1, 2])
    }

    @Test("A list with gaps in its positions is ordered by them before it moves")
    func movingFromGaps() {
        let tags = [makeTag("C", position: 9), makeTag("A", position: 0), makeTag("B", position: 5)]

        let moved = TagRules.moving(tags, from: [0], to: 3)

        #expect(moved.map(\.name) == ["B", "C", "A"] && moved.map(\.position) == [0, 1, 2])
    }

    @Test("Only the tags whose values changed are written")
    func changedTags() {
        let before = [makeTag("A", position: 0), makeTag("B", position: 1), makeTag("C", position: 2)]
        let after = TagRules.moving(before, from: [2], to: 1)

        // B and C swap; A keeps position 0 and is not rewritten.
        #expect(TagRules.changed(from: before, to: after).map(\.name).sorted() == ["B", "C"])
        #expect(TagRules.changed(from: before, to: before).isEmpty)
    }
}
