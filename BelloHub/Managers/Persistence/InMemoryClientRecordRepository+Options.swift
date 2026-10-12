//
//  InMemoryClientRecordRepository+Options.swift
//  BelloHub
//

#if DEBUG
import Foundation

extension InMemoryClientRecordRepository {
    func savedOptions() -> [SavedOption] {
        optionsByID.values.sorted { ($0.context.rawValue, $0.position) < ($1.context.rawValue, $1.position) }
    }

    func save(_ option: SavedOption) {
        optionsByID[option.id] = option
        changes.notify()
    }

    func save(_ options: [SavedOption]) {
        options.forEach { optionsByID[$0.id] = $0 }
        changes.notify()
    }
}
#endif
