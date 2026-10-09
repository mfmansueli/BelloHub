//
//  CatalogRepository.swift
//  BelloHub
//

import Foundation

/// What she offers beyond the services themselves: add-ons, products and credentials (S5). Services stay in
/// `AgendaRepository` because appointments point at them. Non-clinical, stored in the clear (docs/05-DATA-MODEL.md
/// section 1). The services slice of S5 fills this protocol and both vault implementations, in their own files.
protocol CatalogRepository: Sendable {}
