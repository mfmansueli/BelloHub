//
//  AfterWindowReschedule.swift
//  BelloHub
//

/// What a client can do on her own after the free window, when rescheduling.
enum AfterWindowReschedule: String, PersistedEnum {
    /// She sends a request; the current time stays reserved until the professional answers.
    case request
    case message

    static let fallback = AfterWindowReschedule.message
}
