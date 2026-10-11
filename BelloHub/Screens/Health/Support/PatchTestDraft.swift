//
//  PatchTestDraft.swift
//  BelloHub
//

import Foundation

/// What the professional has entered in the "Record patch test" sheet.
struct PatchTestDraft: Equatable, Sendable {
    var product = ""
    var area = ""
    var testedAt: Date
    var observedHours = 24
    var result = PatchTestResult.noReaction
    var notes = ""

    init(testedAt: Date) {
        self.testedAt = testedAt
    }
}
