//
//  ConsentDocumentKind.swift
//  BelloHub
//

/// What a `ConsentDocument` is: a photo she took or picked, or a file (a PDF scan) she chose.
enum ConsentDocumentKind: String, PersistedEnum {
    case photo
    case file

    /// An unknown kind is shown as a file: nothing is assumed about its bytes.
    static let fallback = ConsentDocumentKind.file
}
