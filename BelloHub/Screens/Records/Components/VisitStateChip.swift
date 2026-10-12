//
//  VisitStateChip.swift
//  BelloHub
//

import SwiftUI

/// The record's state on a visit card or its details. Only states worth a look get a chip on a card: a draft. The
/// details also show "Finalized" and "Locked".
struct VisitStateChip: View {
    let state: VisitRecordState
    var showsFinalized = false

    var body: some View {
        switch state {
        case .draft:
            StatusChip(label: "record.status.draft", style: StatusPalette.pending)
        case .open:
            if showsFinalized { StatusChip(label: "record.status.finalized", style: StatusPalette.completed) }
        case .locked:
            if showsFinalized { StatusChip(label: "recordHistory.lock.locked", style: StatusPalette.confirmed) }
        }
    }
}
