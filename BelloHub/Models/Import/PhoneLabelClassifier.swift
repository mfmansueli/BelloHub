//
//  PhoneLabelClassifier.swift
//  BelloHub
//

import Foundation

/// Whether the label a contact or a spreadsheet gives a number says "mobile". The number she wants is the one
/// WhatsApp uses, so a contact with a home, a work and a mobile number is imported with the mobile.
enum PhoneLabelClassifier {
    /// Words that mean mobile in the fourteen localizations and in the labels people type, matched inside the label.
    private static let mobileFragments = [
        "mobile", "mobil", "cell", "celular", "cellulare", "movil", "telemovel", "iphone", "whatsapp", "handy",
        "portable", "جوال", "موبايل", "محمول", "मोबाइल"
    ]
    /// Short abbreviations that count only as a word of their own ("hp" must not match inside "shpping").
    private static let mobileWords: Set<String> = ["hp", "cep", "wpp", "zap", "gsm", "cel"]

    static func isMobile(_ label: String?) -> Bool {
        guard let label, !label.isEmpty else { return false }
        let folded = label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        if mobileFragments.contains(where: { folded.contains($0) }) { return true }
        let words = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return words.contains { mobileWords.contains($0) }
    }
}
