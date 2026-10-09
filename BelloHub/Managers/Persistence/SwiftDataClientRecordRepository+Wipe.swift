//
//  SwiftDataClientRecordRepository+Wipe.swift
//  BelloHub
//

import Foundation
import SwiftData

extension SwiftDataClientRecordRepository {
    /// Every `VaultItem` goes, whatever its kind, in one commit. Photos stored in external storage are deleted with
    /// their items by SwiftData.
    func wipeEverything() throws {
        try modelContext.delete(model: VaultItem.self)
        try commit()
        changes.notify()
    }
}
