//
//  CancelPolicyViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of Cancellations and changes (6.16): the free window, rescheduling, what clients may do after it,
/// the reminder and the grace for late arrivals, with the text clients read built from them by `PolicyRuleText`. Every
/// change is saved as she makes it, through the shared `BookingSetupEditor`.
@MainActor
@Observable
final class CancelPolicyViewModel {
    /// What the note under the cancelling choices says.
    enum CancelNote: Equatable {
        /// Clients must message: they cannot cancel by themselves.
        case blocked
        /// Late cancellations count toward the no-show limit.
        case counts
        case notCounted
    }

    static let graceOptions = [5, 10, 15, 20]
    /// How many times a visit may be moved, in the order of the chips; nil is "no limit".
    static let rescheduleOptions: [Int?] = [1, 2, 3, nil]

    let editor: BookingSetupEditor
    private let ruleText: PolicyRuleText

    init(editor: BookingSetupEditor, localization: AppLocalization, professionalName: String) {
        self.editor = editor
        ruleText = PolicyRuleText(localization: localization, professionalName: professionalName)
    }

    // MARK: - Reading

    var policy: CancellationPolicy { editor.setup.cancellation }
    var noShow: NoShowPolicy { editor.setup.noShow }

    /// The sentences clients read, in the business language.
    var ruleLines: [String] {
        ruleText.lines(cancellation: policy, noShow: noShow)
    }

    var cancelNote: CancelNote {
        if policy.afterWindowCancel == .message { return .blocked }
        return noShow.isOn && noShow.lateCancelCounts ? .counts : .notCounted
    }

    var errorMessage: String? { editor.saveErrorMessage }

    // MARK: - Editing

    func appear() {
        editor.adoptStored()
    }

    func setFreeWindow(_ hours: Int) {
        change { $0.cancellation.freeWindowHours = hours }
    }

    func setClientCanReschedule(_ value: Bool) {
        change { $0.cancellation.clientCanReschedule = value }
    }

    func setMaxReschedules(_ value: Int?) {
        change { $0.cancellation.maxReschedules = value }
    }

    func setAfterWindowCancel(_ value: AfterWindowCancel) {
        change { $0.cancellation.afterWindowCancel = value }
    }

    func setAfterWindowReschedule(_ value: AfterWindowReschedule) {
        change { $0.cancellation.afterWindowReschedule = value }
    }

    func setAskConfirmation(_ value: Bool) {
        change { $0.cancellation.askConfirmation = value }
    }

    func setGraceMinutes(_ minutes: Int) {
        change { $0.cancellation.graceMinutes = minutes }
    }

    func dismissError() {
        editor.dismissSaveError()
    }

    // MARK: - Private

    /// Fire-and-forget for a switch or a chip; the editor shows the change at once.
    private func change(_ edit: @escaping (inout BookingSetup) -> Void) {
        Task { await editor.apply(edit) }
    }
}
