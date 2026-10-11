//
//  RecordResult.swift
//  BelloHub
//

enum RecordResult: String, PersistedEnum {
    case great
    case good
    case neutral
    case reaction

    static let fallback = RecordResult.neutral
}
