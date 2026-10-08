//
//  MoreSummary.swift
//  BelloHub
//

/// The live numbers under the rows of More ("6 tags", "7 fields on"). Pure, so the counting is tested and the View
/// only formats.
struct MoreSummary: Equatable, Sendable {
    /// Tags she has.
    let tagCount: Int
    /// Record fields switched on across her professions, nil until the template is loaded.
    let fieldsOn: Int?

    init(tags: [Tag], template: RecordTemplate?, professions: [ProfessionID]) {
        tagCount = tags.count
        fieldsOn = template?.fieldCounts(for: professions).on
    }
}
