//
//  WorkplaceCountriesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("WorkplaceCountries")
struct WorkplaceCountriesTests {
    @Test("Her business region comes first, then every country by name in the screen's language, once each")
    func order() {
        let codes = WorkplaceCountries.codes(businessRegion: "pt", locale: Locale(identifier: "en_US"))
        #expect(codes.first == "PT")
        #expect(Set(codes).count == codes.count)
        #expect(codes.contains("BR") && codes.contains("DE") && codes.count > 150)
        #expect(!codes.contains("001") && !codes.contains("EU"))
        let rest = Array(codes.dropFirst()).map { WorkplaceCountries.name($0, locale: Locale(identifier: "en_US")) }
        #expect(rest == rest.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }
}
