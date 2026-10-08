//
//  PlanProduct.swift
//  BelloHub
//

/// The two products of the one paid plan "Bello Hub Pro" (D33). Same features, no trial, no introductory offer.
enum PlanProduct: String, CaseIterable, Sendable {
    case monthly = "com.bellohub.pro.monthly"
    case yearly = "com.bellohub.pro.yearly"

    static let groupName = "Bello Hub Pro"
}
