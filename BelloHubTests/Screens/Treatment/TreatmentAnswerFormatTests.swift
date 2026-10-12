//
//  TreatmentAnswerFormatTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("TreatmentAnswerFormat")
struct TreatmentAnswerFormatTests {
    @Test("A technique field reads one saved word per line, trimmed, without empty lines")
    func textLines() {
        #expect(TreatmentAnswerFormat.textLines("Classic lift\n\n  Volume 2D \n") == ["Classic lift", "Volume 2D"])
        #expect(TreatmentAnswerFormat.textLines("").isEmpty)
    }
}
