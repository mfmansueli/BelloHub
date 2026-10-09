//
//  InMemoryClientRecordRepository+MessageLog.swift
//  BelloHub
//

#if DEBUG
import Foundation

extension InMemoryClientRecordRepository {
    func messageLogs(for clientID: UUID) -> [MessageLog] {
        bookingSetupMemory.messageLogsByID.values.filter { $0.clientID == clientID }
            .sorted { ($0.openedAt, $0.id.uuidString) > ($1.openedAt, $1.id.uuidString) }
    }

    func save(_ log: MessageLog) {
        bookingSetupMemory.messageLogsByID[log.id] = log
        changes.notify()
    }
}
#endif
