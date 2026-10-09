//
//  PurchaseOutcome.swift
//  BelloHub
//

/// What came out of a purchase or a restore.
enum PurchaseOutcome: Equatable, Sendable {
    /// The plan is hers now.
    case purchased
    /// She closed the store sheet.
    case cancelled
    /// Apple is asking a parent or the bank first; the plan arrives later through the store's updates.
    case pending
    /// Restore found nothing to restore.
    case nothingToRestore
}
