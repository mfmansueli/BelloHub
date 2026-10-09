//
//  RecordResult+Title.swift
//  BelloHub
//

import Foundation

extension RecordResult {
    /// How the result reads on a chip. Neutral wording: it describes how the visit went, never a judgment of the
    /// client or a diagnosis.
    var title: LocalizedStringResource {
        switch self {
        case .great: "treatmentFlow.result.great"
        case .good: "treatmentFlow.result.good"
        case .neutral: "treatmentFlow.result.neutral"
        case .reaction: "treatmentFlow.result.reaction"
        }
    }
}
