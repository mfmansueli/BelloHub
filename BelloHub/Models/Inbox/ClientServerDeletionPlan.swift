//
//  ClientServerDeletionPlan.swift
//  BelloHub
//

import Foundation

/// Which `deleteClientServerData` calls forget a client on the server (D30, API.md 6.7): her phone (contact row,
/// waitlist, requests) and every booking id the phone knows for her, in groups of at most 200 (the contract's cap).
/// Nothing to send when she has neither a phone nor an online booking. Pure, so it is tested without a queue.
enum ClientServerDeletionPlan {
    static let maxBookingIDsPerCall = 200

    static func actions(phone: String?, bookingIDs: [String]) -> [OutboundAction.Kind] {
        let phone = phone.map { $0.trimmingCharacters(in: .whitespaces) }.flatMap { $0.isEmpty ? nil : $0 }
        var seen = Set<String>()
        let ids = bookingIDs.filter { !$0.isEmpty && seen.insert($0).inserted }
        guard phone != nil || !ids.isEmpty else { return [] }
        guard !ids.isEmpty else { return [.deleteClientServerData(phone: phone, bookingIds: [])] }
        return stride(from: 0, to: ids.count, by: maxBookingIDsPerCall).enumerated().map { index, start in
            let chunk = Array(ids[start..<min(start + maxBookingIDsPerCall, ids.count)])
            // The phone travels once: the first call removes everything tied to it.
            return .deleteClientServerData(phone: index == 0 ? phone : nil, bookingIds: chunk)
        }
    }
}
