//
//  ImportColumnOption.swift
//  BelloHub
//

/// A column of the spreadsheet as the mapping menus list it: its position, the title the file gives it (nil when the
/// file has no header or the cell is blank, and the screen then says "Column 3") and the first value in it, so a file
/// without titles can still be matched by looking at the data.
struct ImportColumnOption: Identifiable, Equatable, Sendable {
    let index: Int
    let title: String?
    let sample: String

    var id: Int { index }

    static func options(for table: ImportTable) -> [ImportColumnOption] {
        let titles = table.headerTitles
        return (0..<table.columnCount).map { column in
            let title = titles[column]
            let sample = table.rows.lazy.map { $0.cell(at: column) }.first { !$0.isEmpty } ?? ""
            return ImportColumnOption(index: column, title: title.isEmpty ? nil : title, sample: sample)
        }
    }
}
