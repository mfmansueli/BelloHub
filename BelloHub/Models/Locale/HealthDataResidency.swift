//
//  HealthDataResidency.swift
//  BelloHub
//

/// Information for the humans and the rollout, not a runtime switch: no region ever gets clinical data
/// on our servers (D2, D21). Wave 4 regions are not opened without a written legal opinion.
enum HealthDataResidency: String, Codable, CaseIterable, Sendable {
    case none
    case review
    case blockingUntilReviewed = "blocking-until-reviewed"
}
