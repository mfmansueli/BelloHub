//
//  MessagingChannel.swift
//  BelloHub
//

/// How the professional reaches her clients by default in a region (docs/16-MARKETS.md section 3).
enum MessagingChannel: String, Codable, CaseIterable, Sendable {
    case whatsapp
    case messages
}
