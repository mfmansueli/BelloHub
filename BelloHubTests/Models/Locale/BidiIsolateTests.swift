//
//  BidiIsolateTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("BidiIsolate")
struct BidiIsolateTests {
    @Test("A value is wrapped in first-strong isolate marks")
    func wrap() {
        #expect(BidiIsolate.wrap("Maria") == "\u{2068}Maria\u{2069}")
    }

    @Test("Phones, times and URLs are wrapped as left-to-right")
    func wrapLeftToRight() {
        #expect(BidiIsolate.wrapLeftToRight("+55 11 91234-5678") == "\u{2066}+55 11 91234-5678\u{2069}")
    }

    @Test("An empty value stays empty, so a missing field does not leave stray marks")
    func empty() {
        #expect(BidiIsolate.wrap("").isEmpty)
        #expect(BidiIsolate.wrapLeftToRight("").isEmpty)
    }

    @Test("Stripping removes every isolate mark and nothing else")
    func strip() {
        let wrapped = "مرحبا \(BidiIsolate.wrap("Maria")) \(BidiIsolate.wrapLeftToRight("14:30"))"

        #expect(BidiIsolate.strip(wrapped) == "مرحبا Maria 14:30")
    }

    @Test("Wrapping and stripping round-trips any value")
    func roundTrip() {
        for value in ["Ana Costa", "سارة أحمد", "प्रिया शर्मा", "O'Brien", "+971 50 123 4567"] {
            #expect(BidiIsolate.strip(BidiIsolate.wrap(value)) == value)
        }
    }
}
