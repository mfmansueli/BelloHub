//
//  FontRegistryTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CoreText
import Testing
import UIKit

@Suite("Fonts")
struct FontRegistryTests {
    @Test("Both bundled fonts register and the registration can be repeated")
    func fontsRegister() {
        #expect(FontRegistry.registerAll())
        #expect(FontRegistry.registerAll())
    }

    @Test("The PostScript names the design system relies on resolve",
          arguments: ["Fraunces-Regular", "Fraunces-SemiBold", "Fraunces-Light",
                      "DMSans-9ptRegular_Regular", "DMSans-9ptRegular_SemiBold", "DMSans-9ptRegular_Medium"])
    func postScriptNamesResolve(name: String) {
        FontRegistry.registerAll()

        #expect(UIFont(name: name, size: 17) != nil, "\(name) did not resolve")
    }

    @Test("The family names Font.custom uses exist")
    func familiesExist() {
        FontRegistry.registerAll()

        #expect(UIFont.familyNames.contains(FontRegistry.serifFamily))
        #expect(UIFont.familyNames.contains(FontRegistry.sansFamily))
    }

    @Test("Both fonts are variable: they expose a weight axis")
    func fontsAreVariable() throws {
        FontRegistry.registerAll()

        for name in ["Fraunces-Regular", "DMSans-9ptRegular_Regular"] {
            let font = try #require(UIFont(name: name, size: 17))
            let axes = CTFontCopyVariationAxes(font as CTFont) as? [[String: Any]] ?? []
            let names = axes.compactMap { $0[kCTFontVariationAxisNameKey as String] as? String }

            #expect(names.contains { $0.localizedCaseInsensitiveContains("weight") }, "\(name) axes: \(names)")
        }
    }

    @Test("Missing files are reported, not ignored")
    func missingFilesAreReported() {
        let empty = Bundle(for: BundleToken.self)

        // The test bundle has no fonts of its own, so registering from it must report failure.
        #expect(!FontRegistry.registerAll(in: empty))
    }

    private final class BundleToken {}
}
