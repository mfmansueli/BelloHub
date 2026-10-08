//
//  FixtureImportFileReader.swift
//  BelloHub
//

#if DEBUG
import Foundation
import UniformTypeIdentifiers

/// A spreadsheet source for UI tests and previews (`-uiSpreadsheet clients`): it names a file at once, so the system's
/// file importer (which a UI test cannot drive) never opens, and answers with text held in memory. DEBUG only.
struct FixtureImportFileReader: ImportFileReading {
    let text: String

    var allowedContentTypes: [UTType] { [.commaSeparatedText] }
    var presetFile: URL? { URL(string: "bellohub-fixture:clients.csv") }

    func readText(at url: URL) async throws -> String { text }

    /// The fixture a `-uiSpreadsheet` value names. `clients` is a semicolon-separated export with a header in
    /// Portuguese, a quoted name that holds a comma, a phone that is not valid, a row with no name and a repeated
    /// phone: every kind of row the import has to sort out.
    static func fixture(named name: String) -> FixtureImportFileReader {
        FixtureImportFileReader(text: [
            "Nome;Telefone;E-mail",
            "Ana Beatriz Costa;+55 11 98765-4321;ana@example.com",
            "Bruna Lima;+55 21 99888-7766;",
            "\"Costa, Carla\";+55 31 98877-6655;carla@example.com",
            "Daniela Rocha;123;",
            ";+55 11 91234-5678;",
            "Elisa Prado;+55 11 98765-4321;"
        ].joined(separator: "\r\n"))
    }
}
#endif
