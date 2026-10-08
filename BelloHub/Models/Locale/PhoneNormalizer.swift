//
//  PhoneNormalizer.swift
//  BelloHub
//

import Foundation

/// Turns what a person types into E.164 (`+5511912345678`), and E.164 into the digits `wa.me` wants.
/// Pure and table-tested with numbers from every preset. Accepts any digit system.
struct PhoneNormalizer: Sendable {
    enum Failure: Error, Equatable {
        case empty
        case tooShort
        case tooLong
        /// A national number whose length no number in the region has.
        case implausibleLength
    }

    let catalog: RegionCatalog

    /// `defaultRegion` is the professional's business region (or the client's chosen country).
    /// A number that starts with `+` or `00` is international and ignores it.
    func normalize(_ input: String, defaultRegion: RegionPreset) -> Result<String, Failure> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        let ascii = DigitNormalizer.ascii(trimmed)
        let digits = ascii.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return .failure(.empty) }

        if ascii.hasPrefix("+") || digits.hasPrefix("00") {
            let international = ascii.hasPrefix("+") ? digits : String(digits.dropFirst(2))
            return validateInternational(international)
        }
        return validateNational(digits, region: defaultRegion)
    }

    /// Digits for `https://wa.me/<digits>`: no plus, no spaces.
    static func whatsAppDigits(fromE164 e164: String) -> String {
        DigitNormalizer.digitsOnly(e164)
    }

    // MARK: - Private

    private func validateInternational(_ digits: String) -> Result<String, Failure> {
        guard digits.count >= 8 else { return .failure(.tooShort) }
        guard digits.count <= 15 else { return .failure(.tooLong) }
        if let region = catalog.preset(matchingInternationalDigits: digits) {
            let national = String(digits.dropFirst(region.callingCode.count))
            // A trunk prefix typed after the country code (+44 0...) is dropped, as phones do.
            let cleaned = stripTrunk(national, region: region)
            if !region.nationalLengths.contains(cleaned.count) { return .failure(.implausibleLength) }
            return .success("+\(region.callingCode)\(cleaned)")
        }
        return .success("+\(digits)")
    }

    private func validateNational(_ digits: String, region: RegionPreset) -> Result<String, Failure> {
        let national = stripTrunk(digits, region: region)
        guard national.count >= 6 else { return .failure(.tooShort) }
        guard region.nationalLengths.contains(national.count) else {
            return .failure(national.count > (region.nationalLengths.max() ?? 15) ? .tooLong : .implausibleLength)
        }
        return .success("+\(region.callingCode)\(national)")
    }

    private func stripTrunk(_ digits: String, region: RegionPreset) -> String {
        guard let trunk = region.trunkPrefix, digits.hasPrefix(trunk) else { return digits }
        return String(digits.dropFirst(trunk.count))
    }
}
