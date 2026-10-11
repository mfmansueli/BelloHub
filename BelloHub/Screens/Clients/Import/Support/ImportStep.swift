//
//  ImportStep.swift
//  BelloHub
//

/// Where the client import is: the sources, the column mapping (spreadsheets only), the choice of who to bring over,
/// and the result.
enum ImportStep: Equatable, Sendable {
    case sources
    case mapping
    case choose
    case result
}
