//
//  InMemoryClientRecordRepository+Wipe.swift
//  BelloHub
//

#if DEBUG
import Foundation

extension InMemoryClientRecordRepository {
    /// Empties every table, the ledger and the singletons.
    func wipeEverything() {
        clientsByID = [:]
        appointmentsByID = [:]
        servicesByID = [:]
        addOnsByID = [:]
        productsByID = [:]
        optionsByID = [:]
        credentialsByID = [:]
        recordsByID = [:]
        correctionsByID = [:]
        incidentsByID = [:]
        photosByID = [:]
        photoDataByID = [:]
        healthFormsByID = [:]
        consentsByID = [:]
        plansByID = [:]
        ledger = [:]
        storedProfile = nil
        tagsByID = [:]
        storedTemplate = nil
        healthFormTemplatesByVersion = [:]
        patchTestsByID = [:]
        bookingSetupMemory = BookingSetupMemory()
        changes.notify()
    }
}
#endif
