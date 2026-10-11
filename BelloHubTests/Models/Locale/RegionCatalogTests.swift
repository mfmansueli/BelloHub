//
//  RegionCatalogTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("RegionCatalog and presets")
struct RegionCatalogTests {
    static func bundled() throws -> RegionCatalog {
        try RegionCatalog.loadBundled()
    }

    @Test("The bundled table loads and has the markets of docs/16-MARKETS.md")
    func bundledTableLoads() throws {
        let catalog = try Self.bundled()

        for code in ["BR", "PT", "ES", "MX", "US", "AR", "CO", "CL", "PE", "IT", "FR", "DE", "AT", "CH",
                     "GB", "IE", "AU", "NZ", "ZA", "IN", "TR", "ID", "SA", "AE"] {
            #expect(catalog.preset(for: code) != nil, "\(code) is missing")
        }
    }

    @Test("Region codes are unique")
    func codesAreUnique() throws {
        let codes = try Self.bundled().presets.map(\.code)

        #expect(Set(codes).count == codes.count)
    }

    @Test("Every preset has a currency, a calling code, a channel and offered localizations that exist")
    func everyPresetIsComplete() throws {
        for preset in try Self.bundled().presets {
            #expect(preset.defaultCurrency.count == 3, "\(preset.code) currency")
            #expect(!preset.callingCode.isEmpty && preset.callingCode.allSatisfy(\.isNumber), "\(preset.code) calling")
            #expect(!preset.localizations.isEmpty, "\(preset.code) localizations")
            #expect(preset.localizations.first == preset.defaultLocalization, "\(preset.code) default first")
            for id in preset.localizations {
                #expect(AppLocalization(rawValue: id) != nil, "\(preset.code) offers unknown localization \(id)")
            }
            #expect((1...4).contains(preset.wave), "\(preset.code) wave")
            #expect(!preset.timeZones.isEmpty, "\(preset.code) time zones")
            #expect(!preset.privacyFrameworkId.isEmpty, "\(preset.code) privacy framework")
        }
    }

    @Test("Every listed time zone is a real IANA identifier")
    func timeZonesAreValid() throws {
        for preset in try Self.bundled().presets {
            for identifier in preset.timeZones {
                #expect(TimeZone(identifier: identifier) != nil, "\(preset.code): \(identifier)")
            }
        }
    }

    @Test("Every currency is one Foundation knows")
    func currenciesAreValid() throws {
        let known = Set(Locale.commonISOCurrencyCodes)

        for preset in try Self.bundled().presets {
            #expect(known.contains(preset.defaultCurrency), "\(preset.code): \(preset.defaultCurrency)")
        }
    }

    @Test("Phone patterns have as many digit slots as the length they are keyed by, and lengths are plausible")
    func phonePatternsAreConsistent() throws {
        for preset in try Self.bundled().presets {
            for (length, pattern) in preset.phonePatterns {
                #expect(pattern.filter { $0 == "#" }.count == Int(length), "\(preset.code) pattern \(pattern)")
                #expect(preset.nationalLengths.contains(Int(length) ?? 0), "\(preset.code) length \(length)")
            }
        }
    }

    @Test("Brazil, Portugal, Spain, Italy, France, Germany, Austria, Switzerland, the UK and Ireland are wave 1 (D36)")
    func waveOneIsBrazilAndEurope() throws {
        let catalog = try Self.bundled()
        let waveOne = Set(catalog.presets(inWave: 1).map(\.code))

        #expect(waveOne == ["BR", "PT", "ES", "IT", "FR", "DE", "AT", "CH", "GB", "IE"])
    }

    @Test("Mexico, the US and Latin America are wave 2, India, Turkey and Indonesia wave 3, the Gulf wave 4")
    func laterWaves() throws {
        let catalog = try Self.bundled()

        #expect(Set(catalog.presets(inWave: 3).map(\.code)) == ["IN", "TR", "ID"])
        #expect(Set(catalog.presets(inWave: 4).map(\.code)) == ["SA", "AE"])
        #expect(catalog.preset(for: "MX")?.wave == 2)
        #expect(catalog.preset(for: "US")?.wave == 2)
    }

    @Test("Gulf regions are blocked until a written legal opinion exists")
    func gulfResidency() throws {
        let catalog = try Self.bundled()

        #expect(catalog.preset(for: "SA")?.healthDataResidency == .blockingUntilReviewed)
        #expect(catalog.preset(for: "AE")?.healthDataResidency == .blockingUntilReviewed)
        #expect(catalog.preset(for: "BR")?.healthDataResidency == HealthDataResidency.none)
    }

    @Test("The United States defaults to Messages, every other market to WhatsApp")
    func messagingChannels() throws {
        for preset in try Self.bundled().presets {
            #expect(preset.messagingChannel == (preset.code == "US" ? .messages : .whatsapp), "\(preset.code)")
        }
    }

    @Test("Brazil's preset matches docs/16-MARKETS.md")
    func brazilPreset() throws {
        let brazil = try #require(try Self.bundled().preset(for: "br"))

        #expect(brazil.defaultCurrency == "BRL")
        #expect(brazil.callingCode == "55")
        #expect(brazil.localizations == ["pt-BR", "en"])
        #expect(brazil.timeZones.first == "America/Sao_Paulo")
        #expect(brazil.timeZones.count == 4)
    }

    // MARK: - Device region fallback

    @Test("A device region in the table gets its own preset")
    func exactPreset() throws {
        let preset = try Self.bundled().preset(deviceRegion: "PT", languageCode: "pt")

        #expect(preset.code == "PT")
    }

    @Test("A region without a preset gets the closest one by language and never fails")
    func closestPreset() throws {
        let catalog = try Self.bundled()

        #expect(catalog.preset(deviceRegion: "NL", languageCode: "nl").defaultLocalization == "en-GB")
        #expect(catalog.preset(deviceRegion: "BE", languageCode: "fr").code == "FR")
        #expect(catalog.preset(deviceRegion: "UY", languageCode: "es").defaultLocalization == "es-419")
        #expect(catalog.preset(deviceRegion: nil, languageCode: nil).defaultLocalization == "en")
        #expect(RegionCatalog.currencyCode(forRegion: "NL") == "EUR")
    }

    @Test("Calling codes match the longest prefix")
    func callingCodeMatching() throws {
        let catalog = try Self.bundled()

        #expect(catalog.preset(matchingInternationalDigits: "5511912345678")?.code == "BR")
        #expect(catalog.preset(matchingInternationalDigits: "351912345678")?.code == "PT")
        #expect(catalog.preset(matchingInternationalDigits: "14155552671")?.code == "US")
        #expect(catalog.preset(matchingInternationalDigits: "353831234567")?.code == "IE")
        #expect(catalog.preset(matchingInternationalDigits: "999000")?.code == nil)
    }
}
