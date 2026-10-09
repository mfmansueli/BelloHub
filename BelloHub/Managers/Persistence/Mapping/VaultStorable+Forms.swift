//
//  VaultStorable+Forms.swift
//  BelloHub
//

import Foundation

// How the health form templates and the patch-test log are stored (docs/05-DATA-MODEL.md section 1). Kept apart from
// `VaultStorable+Models.swift`, which holds the S2 and S3 types.

extension HealthFormTemplate: VaultStorable {
    static var kind: VaultKind { .healthFormTemplate }

    var index: VaultIndex {
        VaultIndex(dateA: createdAt, textKey: "v\(version)")
    }
}

extension PatchTest: VaultStorable {
    static var kind: VaultKind { .patchTest }
    /// What was tested and how the skin reacted is health information; the date and the hours stay in the clear.
    static var sensitiveKeys: Set<String> { ["product", "area", "result", "notes"] }

    var index: VaultIndex {
        VaultIndex(ownerID: clientID, dateA: testedAt)
    }
}
