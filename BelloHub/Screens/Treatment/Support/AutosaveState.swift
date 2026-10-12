//
//  AutosaveState.swift
//  BelloHub
//

import Foundation

/// Where the draft's automatic save stands, for the small status line of the visit form.
enum AutosaveState: Equatable, Sendable {
    /// Nothing written yet, so nothing to save (an empty draft is never stored).
    case idle
    /// A change is waiting or being written.
    case saving
    /// Everything she wrote is in the vault, as of this moment.
    case saved(Date)
    /// The last save did not work; what she wrote is still on screen and is saved again with the next change or the
    /// retry.
    case failed
}
