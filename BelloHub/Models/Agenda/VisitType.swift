//
//  VisitType.swift
//  BelloHub
//

/// What the visit is for. A reaction check is booked after an incident and is linked to the visit that caused it.
enum VisitType: String, PersistedEnum {
    case treatment
    case touchUp
    case reactionCheck

    static let fallback = VisitType.treatment
}
