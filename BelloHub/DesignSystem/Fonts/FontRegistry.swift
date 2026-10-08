//
//  FontRegistry.swift
//  BelloHub
//

import CoreText
import Foundation

/// Registers the bundled variable fonts (Fraunces and DM Sans, SIL OFL) for the process.
/// They are registered at launch instead of through `UIAppFonts` because build settings live in
/// xcconfig files and `UIAppFonts` is an array that `INFOPLIST_KEY_*` cannot express.
/// Idempotent: registering a font that is already registered is reported as success here.
enum FontRegistry {
    /// File names (without extension) of the bundled fonts.
    static let fontFiles = ["Fraunces-VF", "DMSans-VF"]
    /// Family names SwiftUI's `Font.custom` resolves after registration.
    static let serifFamily = "Fraunces"
    static let sansFamily = "DM Sans"

    @discardableResult
    static func registerAll(in bundle: Bundle = .main) -> Bool {
        var allRegistered = true
        for file in fontFiles {
            guard let url = bundle.url(forResource: file, withExtension: "ttf") else {
                allRegistered = false
                continue
            }
            var error: Unmanaged<CFError>?
            let registered = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            // An already-registered font is not a failure: tests and the app both call this.
            let alreadyRegistered = (error?.takeRetainedValue() as? NSError)?.code
                == CTFontManagerError.alreadyRegistered.rawValue
            if !registered && !alreadyRegistered {
                allRegistered = false
            }
        }
        return allRegistered
    }
}
