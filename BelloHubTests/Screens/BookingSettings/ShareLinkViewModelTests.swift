//
//  ShareLinkViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ShareLinkViewModel")
@MainActor
struct ShareLinkViewModelTests {
    private struct Rig {
        let model: ShareLinkViewModel
        let editor: BookingSetupEditor
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
        let booking: FakeBookingRepository
        let clipboard: FakeClipboard
    }

    private func make(slug: String? = nil, localization: AppLocalization = .en) async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        if let slug {
            var setup = BookingSetup.starter(now: TestClock.now)
            setup.slug = slug
            await repository.seed(setup: setup)
        }
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        try await service.load(timeZoneID: "America/Sao_Paulo")
        let editor = BookingSetupEditor(service: service)
        let booking = FakeBookingRepository()
        let clipboard = FakeClipboard()
        let model = ShareLinkViewModel(
            editor: editor, displayName: "Maria Silva", businessName: "Maria Beauty", localization: localization,
            booking: booking, clipboard: clipboard, debounce: .zero, copiedDuration: .milliseconds(30)
        )
        return Rig(model: model, editor: editor, service: service, repository: repository, booking: booking,
            clipboard: clipboard)
    }

    // MARK: - Suggestions and typing

    @Test("The suggestions come from her business name and her name")
    func suggestions() async throws {
        let rig = try await make()
        #expect(rig.model.suggestions == ["maria-beauty", "maria-silva", "maria-silva-maria-beauty"])
        #expect(rig.model.professionalName == "Maria")
    }

    @Test("Typing is cleaned as it goes")
    func typingIsCleaned() async throws {
        let rig = try await make()
        rig.model.updateDraft("María Silva")
        #expect(rig.model.draft == "maria-silva")
    }

    @Test("A text that breaks a rule shows the rule and the server is not asked")
    func invalidTexts() async throws {
        let rig = try await make()
        rig.model.updateDraft("ab")
        #expect(rig.model.status == .invalid(.tooShort))
        rig.model.updateDraft("admin")
        #expect(rig.model.status == .invalid(.reserved))
        rig.model.updateDraft(String(repeating: "a", count: 40))
        #expect(rig.model.draft.count == 30 && rig.model.status != .invalid(.tooLong), "typing is cut at 30")
        let asked = await rig.booking.checked
        #expect(!asked.contains("ab") && !asked.contains("admin"))
    }

    @Test("A trailing hyphen while typing is not an error yet")
    func trailingHyphen() async throws {
        let rig = try await make()
        rig.model.updateDraft("maria ")
        #expect(rig.model.draft == "maria-" && rig.model.status == .idle)
    }

    @Test("Clearing the field clears the status")
    func cleared() async throws {
        let rig = try await make()
        rig.model.updateDraft("maria")
        rig.model.updateDraft("")
        #expect(rig.model.status == .idle && rig.model.draft.isEmpty)
    }

    // MARK: - Checking

    @Test("A free address is available; a taken or reserved one says so", arguments: [
        (SlugAvailability.available, AddressStatus.available), (.taken, .taken), (.reserved, .reserved)
    ])
    func checks(answer: SlugAvailability, expected: AddressStatus) async throws {
        let rig = try await make()
        await rig.booking.setAnswer(answer, for: "maria-silva")
        rig.model.updateDraft("maria-silva")
        #expect(rig.model.status == .checking)
        await Wait.untilMain { rig.model.status != .checking }
        #expect(rig.model.status == expected)
        #expect(await rig.booking.checked == ["maria-silva"])
    }

    @Test("Offline the address cannot be checked and the screen says so instead of an error")
    func offline() async throws {
        let rig = try await make()
        await rig.booking.setFailure(.notPublishedYet)
        rig.model.updateDraft("maria-silva")
        await Wait.untilMain { rig.model.status != .checking }
        #expect(rig.model.status == .unchecked)
        #expect(rig.model.canSaveAddress, "a valid address can be chosen before it can be checked")
    }

    @Test("A network failure is treated the same: valid but unchecked")
    func unreachable() async throws {
        let rig = try await make()
        await rig.booking.setFailure(.unreachable)
        rig.model.updateDraft("maria-silva")
        await Wait.untilMain { rig.model.status != .checking }
        #expect(rig.model.status == .unchecked)
    }

    @Test("An answer for text she has already changed is ignored")
    func staleAnswer() async throws {
        let rig = try await make()
        await rig.model.checkAddress("old-address")
        rig.model.updateDraft("new-address")
        await rig.model.checkAddress("old-address")
        #expect(rig.model.status == .checking || rig.model.status == .available)
        #expect(rig.model.draft == "new-address")
    }

    @Test("The app's own offline repository refuses with notPublishedYet")
    func offlineRepository() async {
        await #expect(throws: BookingRepositoryError.notPublishedYet) {
            _ = try await OfflineBookingRepository().isSlugAvailable("maria")
        }
    }

    // MARK: - Saving

    @Test("A valid address is saved and becomes the link")
    func saves() async throws {
        let rig = try await make()
        rig.model.updateDraft("maria-silva")
        await Wait.untilMain { rig.model.status == .available }
        let saved = await rig.model.saveAddress()
        #expect(saved && rig.model.isAddressSaved)
        #expect(rig.model.savedLink?.display == "bellohub.app/maria-silva")
        #expect(try await rig.repository.bookingSetup()?.slug == "maria-silva")
        #expect(rig.model.qrImage != nil)
        #expect(!rig.model.canSaveAddress, "nothing new to save")
    }

    @Test("A taken, reserved, invalid or unchanged address cannot be saved", arguments: [
        SlugAvailability.taken, .reserved
    ])
    func cannotSave(answer: SlugAvailability) async throws {
        let rig = try await make()
        await rig.booking.setAnswer(answer, for: "maria-silva")
        rig.model.updateDraft("maria-silva")
        await Wait.untilMain { rig.model.status != .checking }
        #expect(!rig.model.canSaveAddress)
        #expect(await rig.model.saveAddress() == false)
        #expect(try await rig.repository.bookingSetup() == nil)
    }

    @Test("A too short address cannot be saved")
    func tooShortCannotSave() async throws {
        let rig = try await make()
        rig.model.updateDraft("ab")
        #expect(!rig.model.canSaveAddress)
    }

    @Test("A failed save keeps the old address and shows the error")
    func saveFailure() async throws {
        let rig = try await make(slug: "old-address")
        rig.model.updateDraft("new-address")
        await Wait.untilMain { rig.model.status != .checking }
        await rig.repository.setFailsWrites(true)
        #expect(await rig.model.saveAddress() == false)
        #expect(rig.model.savedLink?.display == "bellohub.app/old-address")
        #expect(rig.model.errorMessage != nil)
        rig.model.dismissError()
        #expect(rig.model.errorMessage == nil)
    }

    @Test("A saved address is in the field when the screen opens")
    func opensWithSaved() async throws {
        let rig = try await make(slug: "maria-silva")
        #expect(rig.model.draft == "maria-silva" && rig.model.isAddressSaved)
        #expect(rig.model.qrImage != nil && rig.model.texts != nil)
    }

    @Test("Without an address there is no QR code and nothing to share")
    func nothingWithoutAddress() async throws {
        let rig = try await make()
        #expect(rig.model.savedLink == nil && rig.model.qrImage == nil && rig.model.texts == nil)
        rig.model.copyLink()
        rig.model.copyInstagram()
        rig.model.copyWhatsApp()
        #expect(rig.clipboard.written.isEmpty)
    }

    // MARK: - Copying

    @Test("Each copy button puts its own text on the clipboard and says Copied for a moment")
    func copying() async throws {
        let rig = try await make(slug: "maria-silva")
        rig.model.copyLink()
        #expect(rig.clipboard.written.last == "https://bellohub.app/maria-silva" && rig.model.copied == .link)
        rig.model.copyInstagram()
        #expect(rig.clipboard.written.last == "Book with me: bellohub.app/maria-silva" && rig.model.copied
            == .instagram)
        rig.model.copyWhatsApp()
        #expect(rig.clipboard.written.last
            == "Hi! Thanks for your message. You can book with Maria here:\nhttps://bellohub.app/maria-silva")
        #expect(rig.model.copied == .whatsApp)
        await Wait.untilMain { rig.model.copied == nil }
        #expect(rig.model.copied == nil)
    }

    @Test("The host in front of the field is the base address")
    func host() async throws {
        let rig = try await make()
        #expect(rig.model.host == "bellohub.app")
    }
}
