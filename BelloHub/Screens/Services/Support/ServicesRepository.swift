//
//  ServicesRepository.swift
//  BelloHub
//

/// What the service screens need from the vault: the services (`AgendaRepository`, because appointments point at them)
/// and the bulk write of a reorder plus the add-ons (`CatalogRepository`). The narrow slice of
/// `ClientRecordRepository` the ViewModels depend on, so a test passes a small fake.
typealias ServicesRepository = AgendaRepository & CatalogRepository
