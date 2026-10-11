//
//  ServiceTimingRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The "Time around the visit" rules of the service form (D56): extra and processing time from the draft to the
/// service and back, and the choices that keep processing inside the visit.
@Suite("ServiceRules time around the visit")
struct ServiceTimingRulesTests {
    private let english = Locale(identifier: "en_US")

    private func draft(minutes: Int = 90) -> ServiceDraft {
        var draft = ServiceDraft()
        draft.name = "Colour"
        draft.minutes = minutes
        return draft
    }

    @Test("A service with no extra time stays plain: no timing is stored")
    func plain() {
        #expect(ServiceRules.timing(for: draft()) == nil)
        let built = ServiceRules.build(draft(), among: [], locale: english)
        #expect(built?.timing == nil && built?.visitTiming == .noExtraTime)
    }

    @Test("Prep, clean-up and processing go into the service, and the form reads them back")
    func roundTrip() throws {
        var form = draft()
        form.prepMinutes = 10
        form.cleanupMinutes = 15
        form.hasProcessing = true
        form.processingMinutes = 45
        form.processingStartMinutes = 30
        let service = try #require(ServiceRules.build(form, among: [], locale: english))
        #expect(service.timing == VisitTiming(prepMinutes: 10, cleanupMinutes: 15, processingStartMinutes: 30,
                                              processingMinutes: 45))
        let back = ServiceDraft(service, locale: english)
        #expect(back.prepMinutes == 10 && back.cleanupMinutes == 15 && back.hasProcessing)
        #expect(back.processingMinutes == 45 && back.processingStartMinutes == 30)
    }

    @Test("Processing switched off is not saved, whatever its menus still say")
    func processingOff() {
        var form = draft()
        form.hasProcessing = false
        form.processingMinutes = 45
        #expect(ServiceRules.timing(for: form) == nil)
    }

    @Test("Processing that does not fit the visit cannot be saved")
    func processingMustFit() {
        var form = draft(minutes: 60)
        form.hasProcessing = true
        form.processingMinutes = 45
        form.processingStartMinutes = 30
        #expect(ServiceRules.issues(in: form, among: [], locale: english).contains(.processingDoesNotFit))
        #expect(ServiceRules.build(form, among: [], locale: english) == nil)
    }

    @Test("Shortening the visit moves processing earlier, then shortens it, then turns it off")
    func fitting() {
        var form = draft(minutes: 90)
        form.hasProcessing = true
        form.processingMinutes = 45
        form.processingStartMinutes = 40
        form.minutes = 60
        let earlier = ServiceRules.fittingProcessing(form)
        #expect(earlier.processingMinutes == 45 && earlier.processingStartMinutes == 15)
        form.minutes = 30
        let shorter = ServiceRules.fittingProcessing(form)
        #expect(shorter.processingMinutes == 25 && shorter.processingStartMinutes == 5)
        form.minutes = 10
        #expect(!ServiceRules.fittingProcessing(form).hasProcessing)
    }

    @Test("The menus offer only processing that fits, and start times every 5 minutes")
    func choices() {
        #expect(ServiceRules.processingOptions(visitMinutes: 30, including: 20) == [10, 15, 20, 25])
        #expect(ServiceRules.processingStartOptions(visitMinutes: 60, processing: 45, including: 0) == [0, 5, 10, 15])
        #expect(ServiceRules.extraMinuteOptions(including: 7) == [0, 5, 7, 10, 15, 20, 30, 45, 60])
    }

    @Test("A service saved before D56 decodes with no extra time")
    func oldServiceDecodes() throws {
        let saved = try JSONEncoder().encode(Service(name: "Glow", durationMinutes: 60))
        var json = try #require(try JSONSerialization.jsonObject(with: saved) as? [String: Any])
        json.removeValue(forKey: "timing")
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(Service.self, from: old).visitTiming == .noExtraTime)
    }
}
