//
//  AddOnRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("AddOnRules")
struct AddOnRulesTests {
    private let english = Locale(identifier: "en_US")

    private func addOn(_ name: String, minutes: Int = 15, position: Int = 0, offered: Bool = true) -> AddOn {
        AddOn(id: UUID(), name: name, minutes: minutes, priceAmount: nil, isOffered: offered, position: position)
    }

    private func draft(_ name: String, price: String = "", minutes: Int = 15) -> AddOnDraft {
        var draft = AddOnDraft()
        draft.name = name
        draft.priceText = price
        draft.minutes = minutes
        return draft
    }

    @Test("A new add-on starts offered and adds fifteen minutes")
    func defaults() {
        let form = AddOnDraft()
        #expect(form.isOffered && form.minutes == 15 && form.name.isEmpty && form.priceText.isEmpty)
    }

    @Test("A name taken by another add-on is refused, but not by the add-on being edited")
    func nameTaken() {
        let tint = addOn("Eyebrow tint")
        #expect(AddOnRules.nameCheck("EYEBROW TINT", among: [tint]) == .duplicate)
        #expect(AddOnRules.nameCheck("EYEBROW TINT", among: [tint], editing: tint.id) == .accepted("EYEBROW TINT"))
    }

    @Test("Issues name what is wrong, in the order the form shows it")
    func issues() {
        #expect(AddOnRules.issues(in: draft("", price: "x"), among: [], locale: english) == [.nameEmpty, .priceInvalid])
        #expect(AddOnRules.issues(in: draft("LED light"), among: [], locale: english).isEmpty)
        let long = draft(String(repeating: "x", count: 61))
        #expect(AddOnRules.issues(in: long, among: [], locale: english) == [.nameTooLong])
    }

    @Test("The price is optional and read the way her language writes numbers")
    func price() throws {
        let none = try #require(AddOnRules.build(draft("LED"), among: [], locale: english))
        #expect(none.priceAmount == nil)
        let portuguese = Locale(identifier: "pt_BR")
        let brazil = try #require(AddOnRules.build(draft("LED", price: "25,50"), among: [], locale: portuguese))
        #expect(brazil.priceAmount == Decimal(string: "25.5"))
    }

    @Test("A new add-on goes after the last; an edited one keeps its id and place")
    func building() throws {
        let one = addOn("A", position: 0)
        let two = addOn("B", position: 3)
        let fresh = try #require(AddOnRules.build(draft("  New   one "), among: [one, two], locale: english))
        #expect(fresh.name == "New one" && fresh.position == 4)

        var edit = draft("B2", minutes: 30)
        edit.isOffered = false
        let changed = try #require(AddOnRules.build(edit, among: [one, two], editing: two, locale: english))
        #expect(changed.id == two.id && changed.position == 3 && changed.minutes == 30 && !changed.isOffered)
    }

    @Test("An add-on becomes a form and back without losing anything", arguments: ["en_US", "pt_BR", "ar_SA"])
    func roundTrip(localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let original = AddOn(
            id: UUID(), name: "Extractions", minutes: 20, priceAmount: Decimal(string: "30.5"), isOffered: false,
            position: 2
        )
        let rebuilt = try #require(AddOnRules.build(
            AddOnDraft(original, locale: locale), among: [original], editing: original, locale: locale
        ))
        #expect(rebuilt == original)
    }

    @Test("Clients are offered only the add-ons that are switched on, in her order")
    func offered() {
        let list = [addOn("C", position: 2), addOn("A", position: 0, offered: false), addOn("B", position: 1)]
        #expect(AddOnRules.offered(list).map(\.name) == ["B", "C"])
        #expect(AddOnRules.ordered(list).map(\.name) == ["A", "B", "C"])
    }

    @Test("The extra-time menu keeps an old value that is not on the list")
    func minuteOptions() {
        #expect(AddOnRules.minuteOptions(including: 15) == AddOnRules.extraMinuteOptions)
        #expect(AddOnRules.minuteOptions(including: 25).contains(25))
        #expect(AddOnRules.minuteOptions(including: 25) == AddOnRules.minuteOptions(including: 25).sorted())
    }

    @Test("A switch changes only the switch")
    func setting() {
        let tint = addOn("Tint", minutes: 15, position: 4)
        let off = AddOnRules.setting(tint, offered: false)
        #expect(!off.isOffered && off.name == "Tint" && off.minutes == 15 && off.position == 4 && off.id == tint.id)
    }
}
