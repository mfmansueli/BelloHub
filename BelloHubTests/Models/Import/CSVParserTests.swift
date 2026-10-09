//
//  CSVParserTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("CSVParser")
struct CSVParserTests {
    private func fields(_ text: String, delimiter: CSVDelimiter? = nil) -> [[String]] {
        CSVParser.parse(text, delimiter: delimiter).records.map(\.fields)
    }

    // MARK: - RFC 4180

    @Test("Plain comma-separated rows")
    func plainRows() {
        #expect(fields("name,phone\nAna,123\nBia,456") == [["name", "phone"], ["Ana", "123"], ["Bia", "456"]])
    }

    @Test("A quoted field may hold the delimiter")
    func quotedDelimiter() {
        #expect(fields("name,city\n\"Costa, Ana\",Lisbon") == [["name", "city"], ["Costa, Ana", "Lisbon"]])
    }

    @Test("A quoted field may hold line breaks")
    func quotedNewline() {
        let rows = CSVParser.parse("name,note\nAna,\"line one\nline two\"\nBia,ok").records

        #expect(rows.map(\.fields) == [["name", "note"], ["Ana", "line one\nline two"], ["Bia", "ok"]])
        #expect(rows.map(\.number) == [1, 2, 3], "a record that spans two lines is one row")
    }

    @Test("Two quotes inside a quoted field are one quote")
    func escapedQuotes() {
        #expect(fields("a\n\"she said \"\"hi\"\"\"") == [["a"], ["she said \"hi\""]])
    }

    @Test("An empty quoted field is an empty field")
    func emptyQuotedField() {
        #expect(fields("a,b,c\n\"\",x,\"\"") == [["a", "b", "c"], ["", "x", ""]])
    }

    @Test("A quote in the middle of an unquoted field is just a character")
    func quoteInTheMiddle() {
        #expect(fields("5\" pipe,x") == [["5\" pipe", "x"]])
    }

    @Test("A quote after spaces still opens a quoted field")
    func quoteAfterSpaces() {
        #expect(fields("a, \"b, c\",d") == [["a", "b, c", "d"]])
    }

    @Test("An unterminated quote keeps the rest of the file as that field instead of crashing")
    func unterminatedQuote() {
        #expect(fields("a,b\nc,\"never closed\nd,e") == [["a", "b"], ["c", "never closed\nd,e"]])
    }

    // MARK: - Line endings, marks, blanks

    @Test("CRLF, LF and CR all end a row", arguments: ["\r\n", "\n", "\r"])
    func lineEndings(ending: String) {
        #expect(fields("a,b\(ending)1,2\(ending)3,4") == [["a", "b"], ["1", "2"], ["3", "4"]])
    }

    @Test("A byte-order mark at the start is skipped")
    func byteOrderMark() {
        #expect(fields("\u{FEFF}name,phone\nAna,1") == [["name", "phone"], ["Ana", "1"]])
    }

    @Test("Empty trailing lines and blank lines are not rows, but they still count for the row number")
    func blankLines() {
        let rows = CSVParser.parse("a,b\n\n1,2\n\n\n").records

        #expect(rows.map(\.fields) == [["a", "b"], ["1", "2"]])
        #expect(rows.map(\.number) == [1, 3], "the second row is row 3 in Excel")
    }

    @Test("Nothing in, nothing out")
    func empty() {
        #expect(fields("").isEmpty)
        #expect(fields("\n\n\r\n").isEmpty)
    }

    @Test("A last row without a line break is read")
    func noTrailingNewline() {
        #expect(fields("a,b\n1,2") == [["a", "b"], ["1", "2"]])
    }

    @Test("Rows keep the number of fields they have")
    func raggedRows() {
        #expect(fields("a,b,c\n1\n1,2,3,4") == [["a", "b", "c"], ["1"], ["1", "2", "3", "4"]])
    }

    @Test("Names in every script survive")
    func unicode() {
        let text = "nome;tel\nJosé Çağrı;1\nعبد الله;2\nप्रिया शर्मा;3\n李雷;4"

        #expect(fields(text).map { $0[0] } == ["nome", "José Çağrı", "عبد الله", "प्रिया शर्मा", "李雷"])
    }

    // MARK: - Delimiter

    @Test("The delimiter is detected: comma, semicolon and tab")
    func delimiterDetection() {
        #expect(CSVParser.parse("a,b,c\n1,2,3").delimiter == .comma)
        #expect(CSVParser.parse("a;b;c\n1;2;3").delimiter == .semicolon)
        #expect(CSVParser.parse("a\tb\tc\n1\t2\t3").delimiter == .tab)
    }

    @Test("A semicolon file with commas inside the values is still semicolon-separated")
    func commasInsideSemicolonFile() {
        let document = CSVParser.parse("Nome;Obs\nSilva, Ana;vip, sempre\nCosta, Bia;nova")

        #expect(document.delimiter == .semicolon)
        #expect(document.records.map(\.fields) == [
            ["Nome", "Obs"], ["Silva, Ana", "vip, sempre"], ["Costa, Bia", "nova"]
        ])
    }

    @Test("A delimiter inside quotes does not decide the delimiter")
    func quotedDelimitersAreIgnored() {
        let document = CSVParser.parse("name;note\n\"a,b,c,d\";x\n\"e,f,g\";y")

        #expect(document.delimiter == .semicolon)
    }

    @Test("A file with no delimiter at all is one column")
    func oneColumn() {
        let document = CSVParser.parse("Ana Costa\nBia Lima\nCarla Dias")

        #expect(document.delimiter == .comma)
        #expect(document.records.map(\.fields) == [["Ana Costa"], ["Bia Lima"], ["Carla Dias"]])
    }

    @Test("A delimiter given by the caller is used as it is")
    func explicitDelimiter() {
        #expect(fields("a,b;c\n1,2;3", delimiter: .semicolon) == [["a,b", "c"], ["1,2", "3"]])
    }

    @Test("The delimiter that agrees with the header on most lines wins")
    func agreementWins() {
        // The header has two commas and one tab; the rows have two commas each and no tabs.
        let document = CSVParser.parse("a,b\tc,d\n1,2,3\n4,5,6\n7,8,9")

        #expect(document.delimiter == .comma)
    }

    // MARK: - Size

    @Test("2,000 rows parse in well under a second of CPU time")
    func twoThousandRows() {
        var lines = ["Nome;Telefone;E-mail"]
        for index in 1...2_000 {
            let digits = String(format: "%04d", index)
            lines.append("Cliente \(index);(11) 9\(digits)-\(digits);c\(index)@example.com")
        }
        let text = lines.joined(separator: "\r\n")

        var document: CSVDocument?
        let elapsed = CPUTime.measure { document = CSVParser.parse(text) }

        #expect(document?.records.count == 2_001)
        #expect(elapsed < .seconds(1), "took \(elapsed)")
    }
}
