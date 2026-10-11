//
//  ClientImportResult.swift
//  BelloHub
//

import Foundation

/// The outcome of importing a batch of clients through the registration gate.
struct ClientImportResult: Equatable, Sendable {
    /// New clients saved and counted.
    var registered = 0
    /// Rows that matched an existing client (same id or phone) or an earlier row of the batch: skipped, not counted.
    var duplicates = 0
    /// Rows that could not be read (no name, an invalid phone). Filled by the importer, not by the gate.
    var malformed = 0
    /// Rows left out because the free registrations ran out: the paywall is offered for these.
    var blocked = 0

    var total: Int { registered + duplicates + malformed + blocked }
}
