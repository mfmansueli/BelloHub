//
//  SwiftDataClientRecordRepository+MessageLog.swift
//  BelloHub
//

import Foundation

extension SwiftDataClientRecordRepository {
    func messageLogs(for clientID: UUID) throws -> [MessageLog] {
        try values(MessageLog.self, from: items(kind: .messageLog, ownerID: clientID))
            .sorted { ($0.openedAt, $0.id.uuidString) > ($1.openedAt, $1.id.uuidString) }
    }

    func save(_ log: MessageLog) throws {
        try upsert(log)
        try commit()
    }
}
