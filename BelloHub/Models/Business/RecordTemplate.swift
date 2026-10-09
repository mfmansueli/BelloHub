//
//  RecordTemplate.swift
//  BelloHub
//

import Foundation

/// "What do you want to remember about each client?": the fields of the treatment record and the intake items she
/// switched on, per profession. One per vault. Stored in the clear (the field *names* are not clinical; what she
/// writes in them is, and that lives sealed in `TreatmentRecord`).
struct RecordTemplate: Identifiable, Hashable, Codable, Sendable {
    static let singletonID = UUID(uuidString: "B3110000-0000-4000-8000-000000000002") ?? UUID()

    let id: UUID
    var fields: [RecordFieldSetting]
    var intake: [IntakeSetting]
    var updatedAt: Date

    init(fields: [RecordFieldSetting], intake: [IntakeSetting], updatedAt: Date) {
        self.id = Self.singletonID
        self.fields = fields
        self.intake = intake
        self.updatedAt = updatedAt
    }

    /// The fields of one profession, in the catalog's order.
    func fields(for profession: ProfessionID) -> [RecordFieldSetting] {
        fields.filter { $0.profession == profession }
    }

    /// Keys switched on for a profession: what the record form shows.
    func enabledKeys(for profession: ProfessionID) -> [String] {
        fields(for: profession).filter(\.isOn).map(\.key)
    }

    func isIntakeOn(_ item: IntakeItem, for profession: ProfessionID) -> Bool {
        intake.first { $0.profession == profession && $0.item == item }?.isOn ?? false
    }

    /// Fields switched on and fields in total over `professions` ("7 of 8 on"). Fields of a profession she no longer
    /// has are not counted.
    func fieldCounts(for professions: [ProfessionID]) -> (on: Int, total: Int) {
        let counted = fields.filter { professions.contains($0.profession) }
        return (counted.filter(\.isOn).count, counted.count)
    }
}
