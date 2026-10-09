//
//  PublishStatusTextTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("PublishStatusText")
struct PublishStatusTextTests {
    private let summary = LocalizedStringResource("more.row.bookingPage.taking", defaultValue: "Taking bookings")
    private let english = Locale(identifier: "en")

    private func row(_ state: PublishState) -> String {
        PublishStatusText.rowSubtitle(state, pageSummary: summary).resolved(in: english)
    }

    private func link(_ state: PublishState) -> String {
        PublishStatusText.linkStatus(state).resolved(in: english)
    }

    @Test("The More row says 'Not online yet' until the page exists, then the page summary")
    func rowSubtitle() {
        #expect(row(.notOnline) == "Not online yet")
        #expect(row(.publishing(wasOnline: false)) == "Not online yet")
        #expect(row(.error(.offline, wasOnline: false)) == "Needs attention")
        #expect(row(.online) == "Taking bookings")
        #expect(row(.paused(until: nil)) == "Taking bookings")
        #expect(row(.publishing(wasOnline: true)) == "Taking bookings")
        #expect(row(.error(.offline, wasOnline: true)) == "Taking bookings")
    }

    @Test("The link card says preview until online, and never claims a working link it does not have")
    func linkStatus() {
        #expect(link(.notOnline) == "Preview only. The link works once you go online.")
        #expect(link(.error(.needsAddress, wasOnline: false)) == "Preview only. The link works once you go online.")
        #expect(link(.online) == "Online. Clients can book you with this link.")
        #expect(link(.paused(until: nil)) == "Online, not taking bookings right now.")
        #expect(link(.publishing(wasOnline: true)) == "Updating your page…")
        #expect(link(.error(.offline, wasOnline: true)) == "Online, but your latest changes are not on the page yet.")
        #expect(!link(.notOnline).hasPrefix("Online"))
    }

    @Test("Every failure has its own sentence in every language, with no placeholder left")
    func failures() {
        for failure in PublishFailure.allCasesForTests {
            for wasOnline in [false, true] {
                let english = PublishStatusText.failure(failure, wasOnline: wasOnline).resolved(in: self.english)
                #expect(!english.isEmpty && !english.contains("publish.") && !english.contains("%"))
                for localization in AppLocalization.allCases where localization != .en && localization != .enGB {
                    let resource = PublishStatusText.failure(failure, wasOnline: wasOnline)
                    let text = resource.resolved(in: localization.locale)
                    #expect(text != english, "\(failure) in \(localization.rawValue)")
                    #expect(!text.contains("publish."))
                }
            }
        }
    }

    @Test("Offline says differently whether the page is already online")
    func offlineTwoWays() {
        let live = PublishStatusText.failure(.offline, wasOnline: true).resolved(in: english)
        let notYet = PublishStatusText.failure(.offline, wasOnline: false).resolved(in: english)
        #expect(live != notYet)
        #expect(live.contains("online") && notYet.contains("not online yet"))
    }

    @Test("Try again is offered unless she has to change something first")
    func retryOffer() {
        let offered: Set<PublishFailure> = [.offline, .busy, .locked, .rejected]
        for failure in PublishFailure.allCasesForTests {
            #expect(PublishStatusText.offersRetry(failure) == offered.contains(failure))
        }
    }

    @Test("The state knows whether the link works for clients")
    func isLive() {
        #expect(!PublishState.notOnline.isLive && !PublishState.publishing(wasOnline: false).isLive)
        #expect(!PublishState.error(.offline, wasOnline: false).isLive)
        #expect(PublishState.online.isLive && PublishState.paused(until: nil).isLive)
        #expect(PublishState.publishing(wasOnline: true).isLive && PublishState.error(.busy, wasOnline: true).isLive)
    }
}
