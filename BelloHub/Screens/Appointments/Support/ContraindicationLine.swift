//
//  ContraindicationLine.swift
//  BelloHub
//

import Foundation

/// One contraindication the client's answers trigger, with the wording of the question she answered. The screen
/// phrases the sentence around it; the health answers themselves stay on the Health and consent screen.
enum ContraindicationLine: Equatable, Hashable, Sendable {
    /// The question (and, for a choice, the option) as the health form words it.
    case answer(question: String, option: String?)
    /// The form was filled in for someone under 18 (D17).
    case minor
}
