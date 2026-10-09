//
//  QuickRepliesViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("QuickRepliesViewModel")
@MainActor
struct QuickRepliesViewModelTests {
    private struct Rig {
        let model: QuickRepliesViewModel
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
    }

    private func profile(_ localeID: String = "en", zone: String = "America/Sao_Paulo") -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: "Maria Silva", regionCode: "BR", timeZoneID: zone, currencyCode: "BRL", appLocaleID: localeID,
            createdAt: TestClock.now
        )
    }

    private func make(localeID: String = "en", loaded: Bool = true) async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        let model = QuickRepliesViewModel(service: service, profile: profile(localeID), now: { TestClock.now })
        if loaded { await model.loadAsync() }
        return Rig(model: model, service: service, repository: repository)
    }

    // MARK: - Loading

    @Test("The first time the six ready-made messages appear in her language")
    func firstLoad() async throws {
        let rig = try await make(localeID: "pt-BR")
        #expect(rig.model.replies.count == 6 && rig.model.hasLoaded && rig.model.errorMessage == nil)
        #expect(rig.model.replies.map(\.title) == BuiltInQuickReply.allCases.map { $0.title(in: .ptBR) })
        #expect(!rig.model.showsSkeleton)
    }

    @Test("A failed read says so and can be retried")
    func loadFailure() async throws {
        let rig = try await make(loaded: false)
        await rig.repository.setFailsReads(true)
        await rig.model.loadAsync()
        #expect(rig.model.errorMessage != nil && rig.model.replies.isEmpty)
        await rig.repository.setFailsReads(false)
        await rig.model.loadAsync()
        #expect(rig.model.errorMessage == nil && rig.model.replies.count == 6)
    }

    // MARK: - Editing

    @Test("A reply of her own is added at the end and shows in the list")
    func add() async throws {
        let rig = try await make()
        let added = await rig.model.add(title: "Thanks", text: "Thank you {name}!")
        #expect(added?.title == "Thanks" && added?.position == 6)
        #expect(rig.model.replies.count == 7 && rig.model.replies.last?.title == "Thanks")
        #expect(await rig.repository.storedQuickReplies().count == 7)
    }

    @Test("A reply that is not valid is not added")
    func addInvalid() async throws {
        let rig = try await make()
        #expect(await rig.model.add(title: "", text: "Hi") == nil)
        #expect(await rig.model.add(title: "A", text: "  ") == nil)
        #expect(rig.model.replies.count == 6)
    }

    @Test("Saving changes the name and the message of a reply")
    func save() async throws {
        let rig = try await make()
        let late = try #require(rig.model.replies.first { $0.builtIn == .late })
        let saved = await rig.model.save(late, title: "Late again", text: "Hi {name}, 20 minutes late.")
        #expect(saved?.text == "Hi {name}, 20 minutes late.")
        let stored = try #require(rig.model.reply(id: late.id))
        #expect(stored.title == "Late again" && stored.builtIn == .late && stored.position == late.position)
        #expect(rig.model.isEdited(stored))
    }

    @Test("Putting a built-in reply back restores its wording")
    func reset() async throws {
        let rig = try await make()
        let late = try #require(rig.model.replies.first { $0.builtIn == .late })
        let edited = try #require(await rig.model.save(late, title: "X", text: "Changed"))
        let original = try #require(await rig.model.resetToOriginal(edited))
        #expect(original.text == BuiltInQuickReply.late.text(in: .en) && original.title
            == BuiltInQuickReply.late.title(in: .en))
        #expect(!rig.model.isEdited(try #require(rig.model.reply(id: late.id))))
    }

    @Test("A reply she wrote has no original to go back to")
    func noOriginal() async throws {
        let rig = try await make()
        let mine = try #require(await rig.model.add(title: "Mine", text: "Hi"))
        #expect(await rig.model.resetToOriginal(mine) == nil)
    }

    @Test("Her own replies can be deleted; the built-in ones cannot")
    func delete() async throws {
        let rig = try await make()
        let mine = try #require(await rig.model.add(title: "Mine", text: "Hi"))
        #expect(await rig.model.delete(mine))
        #expect(rig.model.replies.count == 6)
        let builtIn = try #require(rig.model.replies.first)
        #expect(await rig.model.delete(builtIn) == false)
        #expect(rig.model.replies.count == 6)
    }

    @Test("A failed save leaves the list as it was and shows the error")
    func saveFailure() async throws {
        let rig = try await make()
        await rig.repository.setFailsWrites(true)
        #expect(await rig.model.add(title: "Mine", text: "Hi") == nil)
        #expect(rig.model.replies.count == 6 && rig.model.saveErrorMessage != nil)
        let late = try #require(rig.model.replies.first { $0.builtIn == .late })
        #expect(await rig.model.save(late, title: "X", text: "Y") == nil)
        #expect(rig.model.reply(id: late.id)?.text == late.text)
        rig.model.dismissSaveError()
        #expect(rig.model.saveErrorMessage == nil)
    }

    @Test("A failed delete keeps the reply")
    func deleteFailure() async throws {
        let rig = try await make()
        let mine = try #require(await rig.model.add(title: "Mine", text: "Hi"))
        await rig.repository.setFailsWrites(true)
        #expect(await rig.model.delete(mine) == false)
        #expect(rig.model.replies.count == 7 && rig.model.saveErrorMessage != nil)
    }

    // MARK: - Preview

    @Test("The preview fills the words for an example client, in the business language and zone")
    func preview() async throws {
        let rig = try await make()
        let text = rig.model.preview(of: "Hi {name}! {service} on {date} at {time}: {link}")
        #expect(text.replacingOccurrences(of: "\u{202F}", with: " ")
            == "Hi Ana! Glow Facial on Saturday, October 3 at 3:00 PM: bellohub.app/maria")
    }

    @Test("The preview uses her own address once she has one")
    func previewLink() async throws {
        let rig = try await make()
        var setup = rig.service.setup
        setup.slug = "maria-silva"
        try await rig.service.saveSetup(setup)
        #expect(rig.model.preview(of: "{link}") == "bellohub.app/maria-silva")
    }

    @Test("The preview is in Portuguese for a Portuguese business, with a 24-hour clock")
    func previewPortuguese() async throws {
        let rig = try await make(localeID: "pt-BR")
        let text = rig.model.preview(of: "{date} {time}")
        #expect(text == "sábado, 3 de outubro 15:00")
    }

    @Test("Unknown words are reported and sent as written")
    func unknown() async throws {
        let rig = try await make()
        #expect(rig.model.unknownWords(in: "Hi {name} {oops}") == ["oops"])
        #expect(rig.model.preview(of: "{oops}") == "{oops}")
    }
}
