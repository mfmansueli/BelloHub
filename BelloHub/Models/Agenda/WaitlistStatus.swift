//
//  WaitlistStatus.swift
//  BelloHub
//

enum WaitlistStatus: String, PersistedEnum {
    case waiting
    case offered
    case booked
    case expired

    static let fallback = WaitlistStatus.waiting
}
