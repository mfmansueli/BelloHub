//
//  OptionContext+Title.swift
//  BelloHub
//

import Foundation

extension OptionContext {
    var title: LocalizedStringResource {
        switch self {
        case .technique: "options.context.technique"
        case .preference: "options.context.preference"
        case .sensitivity: "options.context.sensitivity"
        case .recurringRequest: "options.context.recurringRequest"
        }
    }
}
