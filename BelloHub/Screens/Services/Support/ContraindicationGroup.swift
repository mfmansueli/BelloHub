//
//  ContraindicationGroup.swift
//  BelloHub
//

/// The options that belong to one health question ("Allergies": fragrance, latex, ...), as the picker lists them.
struct ContraindicationGroup: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let options: [ContraindicationOption]
}
