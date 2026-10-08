//
//  HealthRepository.swift
//  BelloHub
//

/// What the health screens need from the vault: the client's forms and consents, and the form templates and
/// patch tests. The narrow slice of `ClientRecordRepository` the ViewModels depend on, so a test passes a small fake.
typealias HealthRepository = ClientRepository & FormTemplateRepository
