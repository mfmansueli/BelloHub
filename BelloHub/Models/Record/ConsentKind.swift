//
//  ConsentKind.swift
//  BelloHub
//

enum ConsentKind: String, PersistedEnum {
    case treatment
    case photos

    static let fallback = ConsentKind.treatment
}
