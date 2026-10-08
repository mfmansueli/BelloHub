//
//  RecordSource.swift
//  BelloHub
//

enum RecordSource: String, PersistedEnum {
    case voice
    case manual

    static let fallback = RecordSource.manual
}
