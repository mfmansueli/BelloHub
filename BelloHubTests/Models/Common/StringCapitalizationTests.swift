//
//  StringCapitalizationTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("String capitalization")
struct StringCapitalizationTests {
    @Test("Only the first letter changes", arguments: [
        ("clientes", "Clientes"), ("aluno(a)", "Aluno(a)"), ("Kundschaft", "Kundschaft"), ("", ""),
        ("hasta lista", "Hasta lista")
    ])
    func firstLetter(raw: String, expected: String) {
        #expect(raw.capitalizedFirstLetter(in: Locale(identifier: "es")) == expected)
    }

    @Test("Turkish keeps its dotted capital I")
    func turkish() {
        #expect("istasyon".capitalizedFirstLetter(in: Locale(identifier: "tr")) == "İstasyon")
        #expect("istasyon".capitalizedFirstLetter(in: Locale(identifier: "en")) == "Istasyon")
    }

    @Test("Scripts without case are left alone")
    func uncased() {
        #expect("مريض".capitalizedFirstLetter(in: Locale(identifier: "ar")) == "مريض")
        #expect("मरीज़".capitalizedFirstLetter(in: Locale(identifier: "hi")) == "मरीज़")
    }
}
