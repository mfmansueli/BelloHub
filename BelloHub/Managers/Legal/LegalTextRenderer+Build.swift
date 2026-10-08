//
//  LegalTextRenderer+Build.swift
//  BelloHub
//

extension LegalTextRenderer.PendingStyle {
    /// A debug build shows an unfilled placeholder as `[[OPERATOR_NAME pending]]`, so nobody mistakes it for a
    /// finished text. A release build only runs with the operator fields filled (the S11 gate blocks it otherwise),
    /// and still never shows a raw `{{TOKEN}}`.
    static var forThisBuild: LegalTextRenderer.PendingStyle {
        #if DEBUG
        .visible
        #else
        .hidden
        #endif
    }
}
