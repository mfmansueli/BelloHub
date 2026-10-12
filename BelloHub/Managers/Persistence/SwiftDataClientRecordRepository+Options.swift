//
//  SwiftDataClientRecordRepository+Options.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func savedOptions() throws -> [SavedOption] {
        try values(SavedOption.self, from: items(kind: .savedOption))
            .sorted { ($0.context.rawValue, $0.position) < ($1.context.rawValue, $1.position) }
    }

    func save(_ option: SavedOption) throws {
        try upsert(option)
        try commit()
    }

    func save(_ options: [SavedOption]) throws {
        // One context save at the end, so a reorder is a single transaction.
        try options.forEach { try upsert($0) }
        try commit()
    }
}
