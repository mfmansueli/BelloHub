//
//  AccountDeletionFlowTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("AccountDeletionFlow")
struct AccountDeletionFlowTests {
    @Test("The export is offered before the destructive confirmation, and only `deleting` may wipe")
    func happyPath() {
        var flow = AccountDeletionFlow.idle
        #expect(!flow.allowsWipe)
        flow = flow.next(.tappedDelete)
        #expect(flow == .offeringExport)
        flow = flow.next(.choseExportFirst).next(.exportFinished)
        #expect(flow == .offeringExport, "exporting keeps her on the offer step")
        flow = flow.next(.proceeded)
        #expect(flow == .confirming)
        #expect(!flow.allowsWipe)
        flow = flow.next(.confirmed)
        #expect(flow == .deleting)
        #expect(flow.allowsWipe)
        flow = flow.next(.finished(.deviceOnly))
        #expect(flow == .done(.deviceOnly))
        #expect(!flow.allowsWipe)
    }

    @Test("A confirmation cannot be skipped: confirmed from idle or from the offer does nothing")
    func noSkipping() {
        #expect(AccountDeletionFlow.idle.next(.confirmed) == .idle)
        #expect(AccountDeletionFlow.offeringExport.next(.confirmed) == .offeringExport)
        #expect(AccountDeletionFlow.idle.next(.proceeded) == .idle)
    }

    @Test("Cancelling from either step goes back to idle; a failure returns to the confirmation")
    func cancelAndFail() {
        #expect(AccountDeletionFlow.offeringExport.next(.cancelled) == .idle)
        #expect(AccountDeletionFlow.confirming.next(.cancelled) == .idle)
        #expect(AccountDeletionFlow.deleting.next(.failed) == .confirming)
        #expect(AccountDeletionFlow.deleting.next(.cancelled) == .deleting, "a deletion in flight cannot be cancelled")
    }
}
