//
//  ConsentKind+Title.swift
//  BelloHub
//

import Foundation

extension ConsentKind {
    /// "Treatment consent", the title shown when the record has no label of its own.
    var title: LocalizedStringResource {
        switch self {
        case .healthForm: "health.consent.healthForm"
        case .treatment: "health.consent.treatment"
        case .photos: "health.consent.photos"
        case .guardian: "health.consent.guardian"
        case .other: "health.consent.other"
        }
    }
}
