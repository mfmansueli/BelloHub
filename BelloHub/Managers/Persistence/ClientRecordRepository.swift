//
//  ClientRecordRepository.swift
//  BelloHub
//

/// The vault's one door (docs/04-ARCHITECTURE.md section 1, boundary 1): the focused repositories together.
/// ViewModels depend on the narrow protocol they need; the app creates one implementation.
protocol ClientRecordRepository: ClientRepository, AgendaRepository, TreatmentRepository, BusinessRepository,
                                 FormTemplateRepository, CatalogRepository, BookingSetupRepository,
                                 MessageLogRepository {}
