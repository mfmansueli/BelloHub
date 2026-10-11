//
//  AfterWindowCancel.swift
//  BelloHub
//

/// What a client can do on her own after the free window, when cancelling.
enum AfterWindowCancel: String, PersistedEnum {
    /// She may cancel, with an honest warning (D12).
    case allow
    /// She must message the professional.
    case message

    static let fallback = AfterWindowCancel.message
}
