//
//  RecordCorrecting.swift
//  BelloHub
//

import Foundation
import Observation

/// What the correction sheet needs from a screen's ViewModel, so the record history and a visit's details share one
/// sheet and one rule (`RecordEditRules`): an open record or a draft is edited directly, a locked one gets a logged
/// correction with a reason.
@MainActor
protocol RecordCorrecting: AnyObject, Observable {
    /// The correction (or edit) she is writing, nil when the sheet is closed.
    var draft: RecordCorrectionDraft? { get set }
    var draftPath: RecordLockPolicy.EditPath { get }
    var draftCurrentValue: String? { get }
    var draftProblem: RecordEditRules.Problem? { get }
    var editableFields: [RecordEditableField] { get }
    var isWorking: Bool { get }
    var actionErrorMessage: String? { get }

    func selectField(_ field: RecordEditableField)
    func cancelCorrection()
    func saveCorrection()
    func dismissActionError()
}
