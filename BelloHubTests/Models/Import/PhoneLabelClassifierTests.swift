//
//  PhoneLabelClassifierTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("PhoneLabelClassifier")
struct PhoneLabelClassifierTests {
    @Test("Labels that mean mobile", arguments: [
        "_$!<Mobile>!$_", "mobile", "Mobile", "iPhone", "Celular", "Telemóvel", "Móvil", "Cellulare", "Handy",
        "Portable", "WhatsApp", "Cep Telefonu", "HP", "جوال", "मोबाइल", "Cell"
    ])
    func mobile(label: String) {
        #expect(PhoneLabelClassifier.isMobile(label))
    }

    @Test("Labels that do not",
          arguments: [nil, "", "_$!<Home>!$_", "Work", "Trabalho", "Casa", "Main", "Fax", "shpping"])
    func notMobile(label: String?) {
        #expect(!PhoneLabelClassifier.isMobile(label))
    }
}
