//
//  PhotoKind.swift
//  BelloHub
//

enum PhotoKind: String, PersistedEnum {
    case before
    case after
    case progress

    static let fallback = PhotoKind.progress
}
