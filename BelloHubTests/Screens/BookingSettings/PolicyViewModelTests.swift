//
//  PolicyViewModelTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// The cancel-policy and no-show-policy ViewModels: each switch and chip lands in the stored policy, and the text
/// clients read follows them.
@Suite("Policy ViewModels")
@MainActor
struct PolicyViewModelTests {
    private struct Rig {
        let editor: BookingSetupEditor
        let service: BookingSetupService
        let repository: FakeBookingSetupRepository
    }

    private func make() async throws -> Rig {
        let repository = FakeBookingSetupRepository()
        let service = BookingSetupService(repository: repository, now: { TestClock.now })
        try await service.load(timeZoneID: "America/Sao_Paulo")
        return Rig(editor: BookingSetupEditor(service: service), service: service, repository: repository)
    }

    private func cancelModel(
        _ editor: BookingSetupEditor, _ localization: AppLocalization = .en
    ) -> CancelPolicyViewModel {
        CancelPolicyViewModel(editor: editor, localization: localization, professionalName: "Maria")
    }

    private func noShowModel(_ editor: BookingSetupEditor) -> NoShowPolicyViewModel {
        NoShowPolicyViewModel(editor: editor, localization: .en, professionalName: "Maria")
    }

    // MARK: - Cancellations and changes

    @Test("Every control writes its value into the stored cancellation policy")
    func cancelControls() async throws {
        let rig = try await make()
        let editor = rig.editor
        let service = rig.service
        let model = cancelModel(editor)
        model.setFreeWindow(48)
        model.setClientCanReschedule(false)
        model.setMaxReschedules(nil)
        model.setAfterWindowCancel(.message)
        model.setAfterWindowReschedule(.message)
        model.setAskConfirmation(true)
        model.setGraceMinutes(20)
        let expected = CancellationPolicy(
            freeWindowHours: 48, clientCanReschedule: false, maxReschedules: nil, afterWindowCancel: .message,
            afterWindowReschedule: .message, askConfirmation: true, graceMinutes: 20
        )
        await Wait.untilMain { service.setup.cancellation == expected }
        #expect(service.setup.cancellation == expected)
        #expect(model.policy == expected)
    }

    @Test("The text clients read follows the policy at once")
    func cancelText() async throws {
        let rig = try await make()
        let editor = rig.editor
        let model = cancelModel(editor)
        #expect(model.ruleLines.count == 5)
        #expect(model.ruleLines[1].hasPrefix("Free changes up to 24 hours before."))
        await editor.apply { $0.cancellation.freeWindowHours = 72 }
        #expect(model.ruleLines[1].hasPrefix("Free changes up to 72 hours before."))
        await editor.apply { $0.noShow.isOn = false }
        #expect(model.ruleLines.count == 4)
    }

    @Test("The text clients read is in the business language, not the phone's")
    func cancelTextLanguage() async throws {
        let rig = try await make()
        let editor = rig.editor
        #expect(cancelModel(editor, .ptBR).ruleLines[1].contains("24"))
        #expect(cancelModel(editor, .ptBR).ruleLines != cancelModel(editor, .en).ruleLines)
    }

    @Test("The note under the cancelling choices follows the choice and the no-show rules")
    func cancelNote() async throws {
        let rig = try await make()
        let editor = rig.editor
        let model = cancelModel(editor)
        #expect(model.cancelNote == .notCounted)
        await editor.apply { $0.noShow.lateCancelCounts = true }
        #expect(model.cancelNote == .counts)
        await editor.apply { $0.noShow.isOn = false }
        #expect(model.cancelNote == .notCounted)
        await editor.apply { $0.cancellation.afterWindowCancel = .message }
        #expect(model.cancelNote == .blocked)
    }

    @Test("The options are the ones the policy accepts")
    func cancelOptions() {
        #expect(CancellationPolicy.freeWindowOptions == [2, 12, 24, 48, 72])
        #expect(CancelPolicyViewModel.graceOptions.allSatisfy { CancellationPolicy.graceRange.contains($0) })
        #expect(CancelPolicyViewModel.rescheduleOptions == [1, 2, 3, nil])
    }

    @Test("A failed save puts the policy back and shows the error")
    func cancelFailure() async throws {
        let rig = try await make()
        let editor = rig.editor
        let repository = rig.repository
        let model = cancelModel(editor)
        await repository.setFailsWrites(true)
        model.setFreeWindow(72)
        await Wait.untilMain { model.errorMessage != nil }
        #expect(model.policy.freeWindowHours == CancellationPolicy.standard.freeWindowHours)
        model.dismissError()
        #expect(model.errorMessage == nil)
    }

    // MARK: - No-show protection

    @Test("Every control writes its value into the stored no-show policy")
    func noShowControls() async throws {
        let rig = try await make()
        let editor = rig.editor
        let service = rig.service
        let model = noShowModel(editor)
        model.setOn(true)
        model.setLimit(4)
        model.setAction(.approveNewBookings)
        model.setLateCancelCounts(true)
        model.setCountingMonths(6)
        let expected = NoShowPolicy(isOn: true, limit: 4, action: .approveNewBookings, lateCancelCounts: true,
            countingMonths: 6)
        await Wait.untilMain { service.setup.noShow == expected }
        #expect(service.setup.noShow == expected)
    }

    @Test("The limit stays between 1 and 5", arguments: [(-3, 1), (0, 1), (1, 1), (3, 3), (5, 5), (6, 5), (99, 5)])
    func limitClamped(asked: Int, stored: Int) async throws {
        let rig = try await make()
        let editor = rig.editor
        let service = rig.service
        let model = noShowModel(editor)
        model.setLimit(asked)
        await Wait.untilMain { service.setup.noShow.limit == stored }
        #expect(service.setup.noShow.limit == stored)
    }

    @Test("The sentence clients read follows the action and the limit, and is gone when protection is off")
    func noShowText() async throws {
        let rig = try await make()
        let editor = rig.editor
        let model = noShowModel(editor)
        #expect(model.ruleLine == "Maria keeps track of appointments that are missed without a message.")
        await editor.apply { $0.noShow.action = .pauseOnline; $0.noShow.limit = 2 }
        #expect(model.ruleLine
            == "After 2 missed appointments without a message, online booking pauses and Maria contacts you.")
        await editor.apply { $0.noShow.isOn = false }
        #expect(model.ruleLine == nil)
    }

    @Test("The two screens say the same no-show sentence")
    func oneOwnerOfTheSentence() async throws {
        let rig = try await make()
        let editor = rig.editor
        let cancel = cancelModel(editor)
        let noShow = noShowModel(editor)
        #expect(cancel.ruleLines.last == noShow.ruleLine)
    }

    @Test("A failed save puts the policy back and shows the error")
    func noShowFailure() async throws {
        let rig = try await make()
        let editor = rig.editor
        let repository = rig.repository
        let model = noShowModel(editor)
        await repository.setFailsWrites(true)
        model.setLimit(5)
        await Wait.untilMain { model.errorMessage != nil }
        #expect(model.policy.limit == NoShowPolicy.standard.limit)
    }

    @Test("The two screens work on one setup: a change on one shows on the other")
    func sharedEditor() async throws {
        let rig = try await make()
        let editor = rig.editor
        let cancel = cancelModel(editor)
        let noShow = noShowModel(editor)
        await editor.apply { $0.cancellation.freeWindowHours = 12 }
        #expect(noShow.cancellation.freeWindowHours == 12)
        await editor.apply { $0.noShow.limit = 5 }
        #expect(cancel.noShow.limit == 5)
    }
}
