//
//  CredentialRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CredentialRules")
struct CredentialRulesTests {
    private let english = Locale(identifier: "en_US")

    private func credential(
        _ title: String, kind: CredentialKind = .training, position: Int = 0, shown: Bool = true,
        number: String? = nil
    ) -> Credential {
        Credential(
            kind: kind, title: title, registrationNumber: number, showOnBookingPage: shown, position: position
        )
    }

    private func draft(_ title: String, institution: String = "", year: String = "") -> CredentialDraft {
        var draft = CredentialDraft()
        draft.title = title
        draft.institution = institution
        draft.yearText = year
        return draft
    }

    // MARK: - Reading the list

    @Test("The courses are listed in her order and the registration is kept apart")
    func reading() {
        let all = [credential("B", position: 1), credential("", kind: .registration, position: 0, number: "123"),
                   credential("A", position: 0)]
        #expect(CredentialRules.trainings(all).map(\.title) == ["A", "B"])
        #expect(CredentialRules.registration(all)?.registrationNumber == "123")
        #expect(CredentialRules.registration([credential("A")]) == nil)
    }

    @Test("The page switch reads on if any credential is shown, and from the fallback when there are none")
    func pageSwitch() {
        #expect(CredentialRules.showsOnPage([], fallback: true))
        #expect(!CredentialRules.showsOnPage([], fallback: false))
        #expect(CredentialRules.showsOnPage([credential("A", shown: false), credential("B")], fallback: false))
        #expect(!CredentialRules.showsOnPage([credential("A", shown: false)], fallback: true))
    }

    @Test("Switching the page off or on changes only the credentials that differ")
    func settingVisibility() {
        let all = [credential("A"), credential("B", shown: false), credential("", kind: .registration, number: "1")]
        let off = CredentialRules.setting(all, show: false)
        #expect(off.map(\.title) == ["A", ""] && off.allSatisfy { !$0.showOnBookingPage })
        let on = CredentialRules.setting(all, show: true)
        #expect(on.map(\.title) == ["B"] && on.allSatisfy(\.showOnBookingPage))
        #expect(CredentialRules.setting([credential("A")], show: true).isEmpty)
    }

    // MARK: - The form

    @Test("A year is read in any digits and an empty field is no year")
    func yearReading() {
        #expect(CredentialRules.year(from: "2019") == 2019)
        #expect(CredentialRules.year(from: " ٢٠١٩ ") == 2019)
        #expect(CredentialRules.year(from: "") == nil)
        #expect(CredentialRules.year(from: "abc") == nil)
    }

    @Test("A year must be four digits between 1950 and next year", arguments: [
        ("2026", true), ("2027", true), ("2028", false), ("1950", true), ("1949", false), ("24", false), ("abc", false),
        ("", true), ("٢٠٢٤", true)
    ])
    func yearRange(text: String, isValid: Bool) {
        let issues = CredentialRules.issues(in: draft("Course", year: text), currentYear: 2026)
        #expect(issues.contains(.yearInvalid) == !isValid)
    }

    @Test("The name is required and limited; the institution is limited")
    func textIssues() {
        #expect(CredentialRules.issues(in: draft(""), currentYear: 2026) == [.titleEmpty])
        #expect(CredentialRules.issues(in: draft("  "), currentYear: 2026) == [.titleEmpty])
        let longTitle = draft(String(repeating: "x", count: 81))
        #expect(CredentialRules.issues(in: longTitle, currentYear: 2026) == [.titleTooLong])
        let long = draft("Course", institution: String(repeating: "i", count: 81))
        #expect(CredentialRules.issues(in: long, currentYear: 2026) == [.institutionTooLong])
        #expect(CredentialRules.issues(in: draft("Course"), currentYear: 2026).isEmpty)
    }

    @Test("A new credential goes after the last and starts with the page switch as it stands")
    func building() throws {
        let existing = [credential("A", position: 4)]
        let shown = try #require(CredentialRules.build(
            draft("  Biosafety   training ", institution: " Senac SP ", year: "2024"), among: existing,
            showOnPage: true, currentYear: 2026
        ))
        #expect(shown.title == "Biosafety training" && shown.institution == "Senac SP" && shown.year == 2024)
        #expect(shown.position == 5 && shown.showOnBookingPage && shown.kind == .training)

        let hidden = try #require(
            CredentialRules.build(draft("Peel"), among: existing, showOnPage: false, currentYear: 2026)
        )
        #expect(!hidden.showOnBookingPage && hidden.year == nil)
    }

    @Test("Editing keeps the id, the place and whether it shows")
    func editing() throws {
        let original = credential("Old", position: 2, shown: false)
        let built = try #require(CredentialRules.build(
            draft("New"), among: [original], editing: original, showOnPage: true, currentYear: 2026
        ))
        #expect(built.id == original.id && built.position == 2 && !built.showOnBookingPage && built.title == "New")
    }

    @Test("A draft with an issue builds nothing")
    func refused() {
        #expect(CredentialRules.build(draft(""), among: [], showOnPage: true, currentYear: 2026) == nil)
        #expect(CredentialRules.build(draft("A", year: "3000"), among: [], showOnPage: true, currentYear: 2026) == nil)
    }

    @Test("A credential becomes a form and back", arguments: ["en_US", "pt_BR", "ar_SA", "hi_IN"])
    func roundTrip(localeID: String) throws {
        let locale = Locale(identifier: localeID)
        let original = Credential(title: "Dermaplaning", institution: "Senac", year: 2022, position: 1)
        let rebuilt = try #require(CredentialRules.build(
            CredentialDraft(original, locale: locale), among: [original], editing: original, showOnPage: true,
            currentYear: 2026
        ))
        #expect(rebuilt == original)
    }

    @Test("The line under a title joins the institution and the year and leaves out what is missing")
    func details() {
        func line(_ institution: String, _ year: Int?) -> String {
            CredentialRules.details(
                of: Credential(title: "T", institution: institution, year: year), locale: english
            )
        }
        #expect(line("Senac SP", 2019) == "Senac SP · 2019")
        #expect(line("", 2022) == "2022")
        #expect(line("Senac SP", nil) == "Senac SP")
        #expect(line("", nil).isEmpty)
    }

    // MARK: - The registration number

    @Test("A first number creates the registration, using the page switch")
    func firstRegistration() {
        let id = UUID()
        let change = CredentialRules.registrationChange(
            text: "  COREN  123456 ", among: [credential("A", position: 2)], showOnPage: false, makeID: { id }
        )
        guard case .save(let saved) = change else {
            Issue.record("expected a save, got \(change)")
            return
        }
        #expect(saved.id == id && saved.kind == .registration && saved.registrationNumber == "COREN 123456")
        #expect(!saved.showOnBookingPage && saved.position == 3 && saved.title.isEmpty)
    }

    @Test("A changed number updates the same credential; the same number changes nothing")
    func changedRegistration() {
        let existing = credential("", kind: .registration, number: "111")
        let change = CredentialRules.registrationChange(text: "222", among: [existing], showOnPage: true)
        guard case .save(let saved) = change else {
            Issue.record("expected a save, got \(change)")
            return
        }
        #expect(saved.id == existing.id && saved.registrationNumber == "222")
        #expect(CredentialRules.registrationChange(text: " 111 ", among: [existing], showOnPage: true) == .none)
    }

    @Test("Emptying the field removes the registration; with none stored it does nothing")
    func removedRegistration() {
        let existing = credential("", kind: .registration, number: "111")
        #expect(CredentialRules.registrationChange(text: "  ", among: [existing], showOnPage: true)
            == .remove(id: existing.id))
        #expect(CredentialRules.registrationChange(text: "", among: [], showOnPage: true) == .none)
    }

    @Test("A number that is too long is not stored")
    func longRegistration() {
        let text = String(repeating: "1", count: 41)
        #expect(!CredentialRules.isValidRegistration(text))
        #expect(CredentialRules.registrationChange(text: text, among: [], showOnPage: true) == .none)
        #expect(CredentialRules.isValidRegistration(String(repeating: "1", count: 40)))
    }
}
