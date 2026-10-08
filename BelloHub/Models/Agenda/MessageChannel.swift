//
//  MessageChannel.swift
//  BelloHub
//

enum MessageChannel: String, PersistedEnum {
    case whatsapp
    case sms
    case share

    static let fallback = MessageChannel.share
}
