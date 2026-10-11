//
//  BookingSettingsViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingSettingsViewModel")
@MainActor
struct BookingSettingsViewModelTests {
    private struct Rig {
        let model: BookingSettingsViewModel
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
        let clipboard: FakeClipboard
    }

    private func profile() -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: "Maria Silva", businessName: "Maria Beauty", regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", createdAt: TestClock.now
        )
    }

    private func make(loaded: Bool = true) async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        let clipboard = FakeClipboard()
        let model = BookingSettingsViewModel(
            service: service, profile: profile(), clipboard: clipboard, copiedDuration: .milliseconds(30),
            now: { TestClock.now }
        )
        if loaded { await model.loadAsync() }
        return Rig(model: model, service: service, repository: repository, clipboard: clipboard)
    }

    // MARK: - Loading

    @Test("Loading shows the starter hours and the standard page when nothing is stored")
    func loadsDefaults() async throws {
        let rig = try await make()
        #expect(rig.model.hasLoaded && rig.model.errorMessage == nil)
        #expect(rig.model.isAccepting && rig.model.link == nil)
        #expect(rig.model.availability.bufferMinutes == 15)
    }

    @Test("A failed read says so and can be retried")
    func loadFailure() async throws {
        let rig = try await make(loaded: false)
        await rig.repository.setFailsReads(true)
        await rig.model.loadAsync()
        #expect(rig.model.errorMessage != nil && rig.model.hasLoaded)
        await rig.repository.setFailsReads(false)
        await rig.model.loadAsync()
        #expect(rig.model.errorMessage == nil)
    }

    @Test("The profile gives the zone, the business language, the first name and the first day of the week")
    func profileDetails() async throws {
        let rig = try await make()
        #expect(rig.model.timeZone.identifier == "America/Sao_Paulo")
        #expect(rig.model.localization == .ptBR)
        #expect(rig.model.professionalName == "Maria")
        #expect(rig.model.firstWeekday == 1, "Brazil starts the week on Sunday")
    }

    // MARK: - Switches

    @Test("Approval of new clients and guests are saved; guests stay between 0 and 2")
    func switches() async throws {
        let rig = try await make()
        rig.model.setConfirmNewClients(true)
        rig.model.setMaxGuests(2)
        await Wait.untilMain { rig.service.setup.page.confirmNewClients && rig.service.setup.page.maxGuests == 2 }
        #expect(rig.service.setup.page.confirmNewClients && rig.service.setup.page.maxGuests == 2)
        rig.model.setMaxGuests(7)
        await Wait.untilMain { rig.service.setup.page.maxGuests == 2 }
        rig.model.setMaxGuests(-1)
        await Wait.untilMain { rig.service.setup.page.maxGuests == 0 }
        #expect(rig.service.setup.page.maxGuests == 0)
    }

    // MARK: - The pause flow

    @Test("Pausing with a return date closes the page until that morning")
    func pauseWithDate() async throws {
        let rig = try await make()
        let returnDay = TestClock.date("2026-10-20 00:00")
        await rig.model.pause(until: returnDay)
        #expect(!rig.model.isAccepting)
        #expect(rig.model.returnDate == returnDay)
        #expect(rig.service.setup.page.pausedUntil == returnDay && !rig.service.setup.page.acceptingBookings)
        #expect(try await rig.repository.bookingSetup()?.page.pausedUntil == returnDay)
    }

    @Test("Pausing with no date is open-ended")
    func pauseWithoutDate() async throws {
        let rig = try await make()
        await rig.model.pause(until: nil)
        #expect(!rig.model.isAccepting && rig.model.returnDate == nil)
        #expect(rig.model.pageState == .paused(until: nil))
    }

    @Test("A return date can be changed and removed while paused")
    func changeReturnDate() async throws {
        let rig = try await make()
        await rig.model.pause(until: TestClock.date("2026-10-20 00:00"))
        await rig.model.setReturnDate(TestClock.date("2026-11-03 10:00"))
        #expect(rig.model.returnDate == TestClock.date("2026-11-03 00:00"))
        await rig.model.setReturnDate(nil)
        #expect(!rig.model.isAccepting && rig.model.returnDate == nil)
    }

    @Test("A return date that is today or earlier is not kept")
    func pastReturnDate() async throws {
        let rig = try await make()
        await rig.model.pause(until: TestClock.date("2026-10-01 20:00"))
        #expect(rig.model.pageState == .paused(until: nil))
    }

    @Test("Opening bookings again forgets the date and keeps the other switches")
    func resume() async throws {
        let rig = try await make()
        rig.model.setConfirmNewClients(true)
        await Wait.untilMain { rig.service.setup.page.confirmNewClients }
        await rig.model.pause(until: TestClock.date("2026-10-20 00:00"))
        await rig.model.resume()
        #expect(rig.model.isAccepting && rig.service.setup.page.pausedUntil == nil)
        #expect(rig.service.setup.page.confirmNewClients)
    }

    @Test("The earliest return date is tomorrow in the business zone")
    func earliest() async throws {
        let rig = try await make()
        #expect(rig.model.earliestReturnDate == TestClock.date("2026-10-02 00:00"))
    }

    @Test("A pause whose day has come shows as open")
    func expiredPause() async throws {
        let repository = FakeBookingSetupRepository()
        var setup = BookingSetup.starter(now: TestClock.now)
        setup.page = BookingPageSettings(
            acceptingBookings: false, pausedUntil: TestClock.date("2026-09-20 00:00"), confirmNewClients: false,
            maxGuests: 0
        )
        await repository.seed(setup: setup)
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        let model = BookingSettingsViewModel(service: service, profile: profile(), now: { TestClock.now })
        await model.loadAsync()
        #expect(model.isAccepting)
    }

    @Test("A failed pause leaves the page open and shows the error")
    func pauseFailure() async throws {
        let rig = try await make()
        await rig.repository.setFailsWrites(true)
        await rig.model.pause(until: nil)
        #expect(rig.model.isAccepting && rig.model.saveErrorMessage != nil)
        rig.model.dismissSaveError()
        #expect(rig.model.saveErrorMessage == nil)
    }

    // MARK: - Rules that live in her availability

    @Test("Buffer, minimum notice and booking window are saved into her availability")
    func rules() async throws {
        let rig = try await make()
        await rig.model.setBuffer(30)
        await rig.model.setMinNoticeHours(12)
        await rig.model.setMaxDaysAhead(90)
        let stored = try #require(try await rig.repository.availability())
        #expect(stored.bufferMinutes == 30 && stored.minNoticeHours == 12 && stored.maxDaysAhead == 90)
        #expect(rig.model.availability == stored)
        #expect(rig.service.availability == stored && !rig.service.isStarterAvailability)
    }

    @Test("The slot interval and Keep my day compact are saved into her availability (D56)")
    func smartSlots() async throws {
        let rig = try await make()
        #expect(rig.model.availability.effectiveSlotStep == 15 && rig.model.availability.keepsDayCompact)
        await rig.model.setSlotStep(FreeSlotsRequest.matchServiceStep)
        await rig.model.setCompactDay(false)
        let stored = try #require(try await rig.repository.availability())
        #expect(stored.slotStepMinutes == 0 && stored.compactDay == false)
        #expect(rig.model.availability == stored)
    }

    @Test("A failed save of a rule puts it back")
    func ruleFailure() async throws {
        let rig = try await make()
        await rig.repository.setFailsWrites(true)
        await rig.model.setBuffer(60)
        #expect(rig.model.availability.bufferMinutes == 15 && rig.model.saveErrorMessage != nil)
    }

    @Test("A value outside the usual options is still offered, so it never disappears from the menu")
    func options() async throws {
        let rig = try await make()
        #expect(rig.model.options([0, 10, 20], including: 15) == [0, 10, 15, 20])
        #expect(rig.model.options([0, 10, 20], including: 10) == [0, 10, 20])
    }

    // MARK: - The link

    @Test("Without an address there is no link; with one it is built from the address")
    func link() async throws {
        let rig = try await make()
        #expect(rig.model.link == nil)
        await rig.model.editor.apply { $0.slug = "maria-silva" }
        #expect(rig.model.link?.display == "bellohub.app/maria-silva")
    }

    @Test("Copying the link puts it on the clipboard and says so for a moment")
    func copyLink() async throws {
        let rig = try await make()
        rig.model.copyLink()
        #expect(rig.clipboard.written.isEmpty, "nothing to copy before she chose an address")
        await rig.model.editor.apply { $0.slug = "maria-silva" }
        rig.model.copyLink()
        #expect(rig.clipboard.written == ["https://bellohub.app/maria-silva"])
        #expect(rig.model.copiedLink)
        await Wait.untilMain { !rig.model.copiedLink }
        #expect(!rig.model.copiedLink)
    }

    // MARK: - Summaries

    @Test("The row under More says whether the page takes bookings and until when it is paused")
    func summaries() {
        let zone = TestClock.saoPaulo
        let formatters = Formatters(locale: Locale(identifier: "en_US"), timeZone: zone, currencyCode: "BRL")
        func text(_ settings: BookingPageSettings) -> String {
            String(localized: BookingSetupSummary.page(settings, now: TestClock.now, timeZone: zone,
                formatters: formatters))
        }
        #expect(text(.standard) == "Taking bookings")
        #expect(text(BookingPause.pausing(.standard, until: nil, now: TestClock.now, timeZone: zone)) == "Paused")
        let until = BookingPause.pausing(.standard, until: TestClock.date("2026-10-20 00:00"), now: TestClock.now,
            timeZone: zone)
        #expect(text(until) == "Paused until Oct 20")
        #expect(String(localized: BookingSetupSummary.noShow(.standard)) == "On · limit 3")
        var off = NoShowPolicy.standard
        off.isOn = false
        #expect(String(localized: BookingSetupSummary.noShow(off)) == "Off")
        #expect(String(localized: BookingSetupSummary.cancellation(.standard, formatters: formatters))
            == "Free up to 24 hr")
    }
}
