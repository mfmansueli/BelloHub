//
//  AccountDeletionFlow.swift
//  BelloHub
//

/// The steps of deleting an account (7.1), as a pure state machine so the order is tested: the export is offered
/// first, the destructive confirmation comes second, and nothing on the device is touched before `confirmed`.
enum AccountDeletionFlow: Equatable, Sendable {
    case idle
    /// The sheet that offers "Export my data first", "Delete everything" and "Keep my account".
    case offeringExport
    /// The final, explicit confirmation ("Delete everything?").
    case confirming
    case deleting
    case done(AccountDeletionOutcome)

    enum Event: Equatable, Sendable {
        case tappedDelete
        case choseExportFirst
        case exportFinished
        case proceeded
        case confirmed
        case cancelled
        case failed
        case finished(AccountDeletionOutcome)
    }

    /// The next step, or the same one when the event does not apply (a late tap never skips a confirmation).
    func next(_ event: Event) -> AccountDeletionFlow {
        switch (self, event) {
        case (.idle, .tappedDelete): return .offeringExport
        case (.offeringExport, .choseExportFirst): return .offeringExport
        case (.offeringExport, .exportFinished): return .offeringExport
        case (.offeringExport, .proceeded): return .confirming
        case (.confirming, .confirmed): return .deleting
        case (.deleting, .finished(let outcome)): return .done(outcome)
        case (.deleting, .failed): return .confirming
        case (.offeringExport, .cancelled), (.confirming, .cancelled): return .idle
        default: return self
        }
    }

    /// Only this state may clear the vault.
    var allowsWipe: Bool { self == .deleting }
}
