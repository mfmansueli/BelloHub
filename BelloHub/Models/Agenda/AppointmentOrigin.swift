//
//  AppointmentOrigin.swift
//  BelloHub
//

enum AppointmentOrigin: String, PersistedEnum {
    case bookingLink
    case manual

    static let fallback = AppointmentOrigin.manual
}
