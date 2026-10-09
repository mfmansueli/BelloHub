//
//  SchedulingWarningTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("SchedulingWarningText")
struct SchedulingWarningTextTests {
    private let formatters = Formatters(
        locale: Locale(identifier: "en_US"), timeZone: TestClock.saoPaulo, currencyCode: "BRL"
    )

    private func text(neighbour: String? = "Beatriz Lima") -> SchedulingWarningText {
        SchedulingWarningText(
            clientName: "Ana Costa", serviceName: "Brazilian Glow", neighbourName: { _ in neighbour },
            catalog: makeHealthCatalog(), formatters: formatters
        )
    }

    private func resolved(_ resource: LocalizedStringResource?) -> String {
        resource.map { String(localized: $0) } ?? ""
    }

    @Test("Every warning has a title and a stable key, and the key is unique per kind")
    func keys() {
        let match = ContraindicationReport.Match(token: "pregnancy", questionKey: "pregnancy", optionKey: nil)
        let all: [SchedulingWarning] = [
            .inThePast, .overlap(with: UUID()), .blocked, .dayOff, .closedDay, .outsideHours(.afterClosing),
            .insideBreak(label: "Lunch"), .buffer(minutes: 15, neighbour: UUID()), .missingPatchTest(hoursBefore: 48),
            .patchTestReaction, .contraindicated([match]), .noHealthForm, .cancelsOften(cancelled: 2, noShows: 1)
        ]
        let entries = text().entries(for: all)
        #expect(entries.count == all.count)
        #expect(Set(entries.map(\.key)).count == all.count)
        #expect(entries.allSatisfy { !resolved($0.title).isEmpty })
    }

    @Test("The time warnings are amber, the health ones coral, and her habits are only information")
    func tones() {
        let words = text()
        #expect(words.entry(for: .blocked).tone == .warning)
        #expect(words.entry(for: .missingPatchTest(hoursBefore: 48)).tone == .safety)
        #expect(words.entry(for: .contraindicated([])).tone == .safety)
        #expect(words.entry(for: .cancelsOften(cancelled: 1, noShows: 0)).tone == .info)
        #expect(words.entry(for: .noHealthForm).tone == .info)
    }

    @Test("An overlap names the other visit's client, or says another appointment when it cannot")
    func overlapNames() {
        let named = text().entry(for: .overlap(with: UUID()))
        #expect(resolved(named.title).contains("Beatriz Lima"))
        let unknown = text(neighbour: nil).entry(for: .overlap(with: UUID()))
        #expect(resolved(unknown.title) == "Overlaps with another appointment.")
    }

    @Test("The patch-test message says how long before the visit it is asked for")
    func patchTest() {
        let entry = text().entry(for: .missingPatchTest(hoursBefore: 48))
        #expect(resolved(entry.title).contains("Ana Costa"))
        #expect(resolved(entry.message).contains("Brazilian Glow") && resolved(entry.message).contains("48"))
    }

    @Test("A contraindication names the questions and choices that matched, and the minor token says under 18")
    func contraindication() {
        let matches = [
            ContraindicationReport.Match(token: "pregnancy", questionKey: "pregnancy", optionKey: nil),
            ContraindicationReport.Match(token: "allergies.latex", questionKey: "allergies", optionKey: "latex"),
            ContraindicationReport.Match(token: "minor", questionKey: nil, optionKey: nil)
        ]
        let message = resolved(text().entry(for: .contraindicated(matches)).message)
        #expect(message.contains("Pregnant or breastfeeding"))
        #expect(message.contains("Allergies: Latex"))
        #expect(message.contains("Under 18"))
        #expect(message.contains("Brazilian Glow"))
    }

    @Test("A break warning carries the break's own name")
    func breakName() {
        #expect(resolved(text().entry(for: .insideBreak(label: "Coffee")).title).contains("Coffee"))
    }

    @Test("The buffer warning says how long she likes to keep between visits")
    func bufferMinutes() {
        #expect(resolved(text().entry(for: .buffer(minutes: 15, neighbour: UUID())).message).contains("15"))
    }
}
