//
//  RecordStatus.swift
//  BelloHub
//

/// Where a treatment record stands. A draft is her work in progress: it is saved as she goes, so nothing is lost
/// when the app closes, and it never locks. Finalizing is her decision; from then on the 24-hour lock runs
/// (`RecordLockPolicy`). A record saved before drafts existed reads as finalized.
enum RecordStatus: String, PersistedEnum {
    case draft
    case finalized

    static let fallback = RecordStatus.finalized
}
