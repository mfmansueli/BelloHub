//
//  UITestPermissionProvider.swift
//  BelloHub
//

#if DEBUG
/// Answers every permission request with "granted" and never shows a system dialog, so a UI test can walk the whole
/// onboarding. DEBUG only.
struct UITestPermissionProvider: PermissionProviding {
    func status(of kind: PermissionKind) async -> PermissionStatus { .notDetermined }
    func request(_ kind: PermissionKind) async -> PermissionStatus { .granted }
}
#endif
