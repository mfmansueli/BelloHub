//
//  PermissionStatus.swift
//  BelloHub
//

/// Where a permission stands. Anything the system calls restricted counts as denied: she cannot change it here.
enum PermissionStatus: Equatable, Sendable {
    case notDetermined
    case granted
    case denied
}
