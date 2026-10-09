//
//  RecordFieldDraft.swift
//  BelloHub
//

import Foundation

/// The values of the "Add your own field" sheet while she fills it in. The options are one text with a line per
/// option, because that is what a text field can hold; `options` is the cleaned list the rules work with.
struct RecordFieldDraft: Equatable, Sendable {
    var name = ""
    var kind = RecordFieldKind.text
    var optionsText = ""
    var unit = ""

    init() {}

    /// A draft that starts from a field she already has, for renaming and changing its options.
    init(editing field: RecordFieldSetting) {
        name = field.customName ?? ""
        kind = field.kind
        optionsText = field.options.joined(separator: "\n")
        unit = field.unit ?? ""
    }

    /// The options she typed: one per line, whitespace collapsed, blank lines and repeats dropped.
    var options: [String] { RecordTemplateEditor.parseOptions(optionsText) }
}
