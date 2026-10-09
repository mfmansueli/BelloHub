//
//  ExportFileNameTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("ExportFileName")
struct ExportFileNameTests {
    @Test("The file name is the client's name joined by dashes, then the suffix", arguments: [
        ("Ana Costa", "record", "Ana-Costa-record.pdf"),
        ("João da Conceição", "ficha", "Joao-da-Conceicao-ficha.pdf"),
        ("  Maria   Beatriz  ", "record", "Maria-Beatriz-record.pdf"),
        ("O'Brien / Smith", "record", "O-Brien-Smith-record.pdf"),
        ("", "record", "record.pdf"),
        ("../../etc", "record", "etc-record.pdf")
    ])
    func name(client: String, suffix: String, expected: String) {
        #expect(ExportFileName.make(clientName: client, suffix: suffix) == expected)
    }

    @Test("A name in another script is kept and never leaves a path separator")
    func otherScripts() {
        let arabic = ExportFileName.make(clientName: "أنا كوستا", suffix: "record")
        #expect(arabic.hasSuffix("-record.pdf"))
        #expect(!arabic.contains("/"))
    }
}
