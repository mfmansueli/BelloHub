//
//  NoShowPolicyViewModel.swift
//  BelloHub
//

import Foundation
import Observation

/// State and actions of No-show protection (6.15): on or off, the limit, whether a late cancellation counts, how long a
/// no-show counts and what happens at the limit. The sentence clients read is `PolicyRuleText`'s, the same one the
/// cancellation screen shows. Every change is saved as she makes it, through the shared `BookingSetupEditor`.
@MainActor
@Observable
final class NoShowPolicyViewModel {
    let editor: BookingSetupEditor
    private let ruleText: PolicyRuleText

    init(editor: BookingSetupEditor, localization: AppLocalization, professionalName: String) {
        self.editor = editor
        ruleText = PolicyRuleText(localization: localization, professionalName: professionalName)
    }

    // MARK: - Reading

    var policy: NoShowPolicy { editor.setup.noShow }
    var cancellation: CancellationPolicy { editor.setup.cancellation }

    /// What clients read about the rule, or nil while protection is off.
    var ruleLine: String? { ruleText.noShowLine(policy) }

    var errorMessage: String? { editor.saveErrorMessage }

    // MARK: - Editing

    func appear() {
        editor.adoptStored()
    }

    func setOn(_ value: Bool) {
        change { $0.noShow.isOn = value }
    }

    /// The limit, kept inside 1 to 5.
    func setLimit(_ value: Int) {
        let limit = min(max(value, NoShowPolicy.limitRange.lowerBound), NoShowPolicy.limitRange.upperBound)
        change { $0.noShow.limit = limit }
    }

    func setAction(_ value: NoShowAction) {
        change { $0.noShow.action = value }
    }

    func setLateCancelCounts(_ value: Bool) {
        change { $0.noShow.lateCancelCounts = value }
    }

    func setCountingMonths(_ months: Int) {
        change { $0.noShow.countingMonths = months }
    }

    func dismissError() {
        editor.dismissSaveError()
    }

    // MARK: - Private

    private func change(_ edit: @escaping (inout BookingSetup) -> Void) {
        Task { await editor.apply(edit) }
    }
}
