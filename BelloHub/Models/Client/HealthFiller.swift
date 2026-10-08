//
//  HealthFiller.swift
//  BelloHub
//

enum HealthFiller: String, PersistedEnum {
    case client
    case professional

    static let fallback = HealthFiller.professional
}
