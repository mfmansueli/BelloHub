//
//  String+Capitalization.swift
//  BelloHub
//

import Foundation

extension String {
    /// Only the first letter upper-cased, in the language's own rules ("clientes" becomes "Clientes"; Turkish "i"
    /// becomes "İ"; scripts without case are left alone). `capitalized` would also change the rest of a phrase.
    func capitalizedFirstLetter(in locale: Locale) -> String {
        guard let first else { return self }
        return String(first).uppercased(with: locale) + dropFirst()
    }
}
