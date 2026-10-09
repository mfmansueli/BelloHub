//
//  ImportRegionTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Testing

@Suite("ImportRegion")
struct ImportRegionTests {
    @Test("Her business region reads the numbers")
    func businessRegion() throws {
        let catalog = try RegionCatalogTests.bundled()

        let preset = ImportRegion.preset(code: "PT", in: catalog, deviceRegion: "BR", languageCode: "pt")

        #expect(preset?.code == "PT")
    }

    @Test("Without a profile (the setup) the phone's own region is the fallback")
    func deviceRegion() throws {
        let catalog = try RegionCatalogTests.bundled()

        #expect(ImportRegion.preset(code: nil, in: catalog, deviceRegion: "MX", languageCode: "es")?.code == "MX")
        #expect(ImportRegion.preset(code: "XX", in: catalog, deviceRegion: "FR", languageCode: "fr")?.code == "FR")
    }

    @Test("An empty region table gives no region instead of crashing")
    func emptyCatalog() {
        let empty = RegionCatalog(presets: [])

        #expect(ImportRegion.preset(code: "BR", in: empty, deviceRegion: "BR", languageCode: "pt") == nil)
    }
}
