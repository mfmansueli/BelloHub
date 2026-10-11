//
//  ImportTextDecoderTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ImportTextDecoder")
struct ImportTextDecoderTests {
    private let sample = "Nome;Telefone\nJosé Çağrı;11 98765-4321\nعبد الله;2"

    @Test("UTF-8 is read as it is")
    func utf8() throws {
        let data = try #require(sample.data(using: .utf8))

        #expect(ImportTextDecoder.decode(data) == sample)
    }

    @Test("UTF-8 with a byte-order mark loses the mark")
    func utf8WithMark() throws {
        let data = Data([0xEF, 0xBB, 0xBF]) + (try #require(sample.data(using: .utf8)))

        #expect(ImportTextDecoder.decode(data) == sample)
    }

    @Test("UTF-16 with a mark, little-endian and big-endian")
    func utf16WithMark() throws {
        let little = Data([0xFF, 0xFE]) + (try #require(sample.data(using: .utf16LittleEndian)))
        let big = Data([0xFE, 0xFF]) + (try #require(sample.data(using: .utf16BigEndian)))

        #expect(ImportTextDecoder.decode(little) == sample)
        #expect(ImportTextDecoder.decode(big) == sample)
    }

    @Test("UTF-16 without a mark is recognised by its zero bytes")
    func utf16WithoutMark() throws {
        let text = "Name;Phone\nAna;1\nBia;2"
        let little = try #require(text.data(using: .utf16LittleEndian))
        let big = try #require(text.data(using: .utf16BigEndian))

        #expect(ImportTextDecoder.decode(little) == text)
        #expect(ImportTextDecoder.decode(big) == text)
    }

    @Test("Windows-1252, which Excel for Windows writes, is the fallback for bytes that are not UTF-8")
    func windows1252() throws {
        let text = "Nome;Telefone\nJosé;Conceição\nÂngela;€"
        let data = try #require(text.data(using: .windowsCP1252))

        #expect(ImportTextDecoder.decode(data) == text)
    }

    @Test("Bytes that no encoding claims still decode, as Latin-1")
    func latin1Fallback() {
        // 0x81 is undefined in Windows-1252, so the Latin-1 fallback decides.
        let text = ImportTextDecoder.decode(Data([0x41, 0x81, 0x42]))

        #expect(text.count == 3 && text.hasPrefix("A") && text.hasSuffix("B"))
    }

    @Test("Nothing decodes to nothing")
    func empty() {
        #expect(ImportTextDecoder.decode(Data()) == "")
    }

    @Test("A decoded file parses into the same rows whatever its encoding")
    func sameRowsInEveryEncoding() throws {
        let text = "Nome;Telefone\nJosé;11 98765-4321"
        let encodings: [Data] = [
            try #require(text.data(using: .utf8)),
            Data([0xEF, 0xBB, 0xBF]) + (try #require(text.data(using: .utf8))),
            Data([0xFF, 0xFE]) + (try #require(text.data(using: .utf16LittleEndian))),
            try #require(text.data(using: .windowsCP1252))
        ]

        for data in encodings {
            #expect(CSVParser.parse(ImportTextDecoder.decode(data)).records.map(\.fields)
                == [["Nome", "Telefone"], ["José", "11 98765-4321"]])
        }
    }
}
