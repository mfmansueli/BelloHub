//
//  QuickReplyIssue.swift
//  BelloHub
//

/// Why a quick reply cannot be saved. The editor says so under the field while she types.
enum QuickReplyIssue: Equatable, Sendable {
    case nameEmpty
    case textEmpty
    case textTooLong
}
