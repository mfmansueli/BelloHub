//
//  ProfessionalProfileTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ProfessionalProfile and ClientTerm")
struct ProfessionalProfileTests {
    private func makeProfile(name: String = "Maria Silva", business: String = "") -> ProfessionalProfile {
        ProfessionalProfile(
            displayName: name, businessName: business, regionCode: "BR", timeZoneID: "America/Sao_Paulo",
            currencyCode: "BRL", appLocaleID: "pt-BR", createdAt: TestClock.now
        )
    }

    @Test("The greeting uses the first word of her name")
    func firstName() {
        #expect(makeProfile(name: "Maria Silva").firstName == "Maria")
        #expect(makeProfile(name: "Maria").firstName == "Maria")
        #expect(makeProfile(name: "").firstName == "")
    }

    @Test("The public name is the business when there is one, otherwise hers")
    func publicName() {
        #expect(makeProfile(business: "Maria Beauty").publicName == "Maria Beauty")
        #expect(makeProfile().publicName == "Maria Silva")
    }

    @Test("There is one profile per vault, so its id never changes")
    func singleton() {
        #expect(makeProfile().id == ProfessionalProfile.singletonID)
        #expect(makeProfile(name: "Other").id == makeProfile().id)
        #expect(ProfessionalProfile.singletonID != RecordTemplate.singletonID)
    }

    @Test("A profile round-trips through JSON, and an unknown term or profession reads as the fallback")
    func codable() throws {
        var profile = makeProfile()
        profile.professions = [.esthetician, .massage]
        profile.clientTerm = .student
        let decoded = try JSONDecoder().decode(ProfessionalProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded == profile)

        let future = Data(#"["astronaut"]"#.utf8)
        #expect(try JSONDecoder().decode([ProfessionID].self, from: future) == [.other])
        #expect(try JSONDecoder().decode([ClientTerm].self, from: Data(#"["comrade"]"#.utf8)) == [.client])
    }

    @Test("Every term has a singular and a plural in the shipped catalog", arguments: AppLocalization.allCases)
    func termsAreTranslated(localization: AppLocalization) {
        for term in ClientTerm.allCases {
            let singular = term.singularText(in: localization.locale)
            let plural = term.pluralText(in: localization.locale)
            #expect(!singular.isEmpty && !plural.isEmpty)
            #expect(!singular.hasPrefix("term.") && !plural.hasPrefix("term."), "\(term) in \(localization)")
        }
    }

    @Test("Titles are capitalized in the reader's language")
    func titles() {
        let portuguese = Locale(identifier: "pt-BR")
        #expect(ClientTerm.client.titlePlural(in: portuguese) == "Clientes")
        #expect(ClientTerm.patient.titleSingular(in: portuguese) == "Paciente")
        #expect(ClientTerm.client.titlePlural(in: Locale(identifier: "en")) == "Clients")
        #expect(ClientTerm.client.titlePlural(in: Locale(identifier: "de")) == "Kundschaft")
    }
}
