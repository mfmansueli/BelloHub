//
//  QuickAccessViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@MainActor
@Suite("QuickAccessViewModel")
struct QuickAccessViewModelTests {
    private func makeLink() -> BookingLink {
        BookingLink(slug: "maria-silva")
    }

    @Test("Copying puts the full address on the clipboard and says Copied")
    func copies() {
        let clipboard = FakeClipboard()
        let model = QuickAccessViewModel(clipboard: clipboard)

        model.copy(makeLink())

        #expect(clipboard.written == [makeLink().url.absoluteString])
        #expect(model.copiedLink)
    }

    @Test("Copied goes away by itself after a moment")
    func copiedResets() async {
        let model = QuickAccessViewModel(clipboard: FakeClipboard(), copiedDuration: .milliseconds(20))

        model.copy(makeLink())

        #expect(await Wait.untilMain { !model.copiedLink })
    }
}
