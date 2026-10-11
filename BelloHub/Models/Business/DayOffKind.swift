//
//  DayOffKind.swift
//  BelloHub
//

enum DayOffKind: String, PersistedEnum {
    case dayOff
    case vacation
    case blocked

    static let fallback = DayOffKind.blocked
}
