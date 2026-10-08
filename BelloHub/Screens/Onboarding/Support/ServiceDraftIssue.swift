//
//  ServiceDraftIssue.swift
//  BelloHub
//

/// Why a custom service cannot be added yet.
enum ServiceDraftIssue: Equatable, Sendable {
    case nameMissing
    case priceNegative
}
