//
//  ConsentDocument.swift
//  BelloHub
//

import Foundation

/// A photo or a file of the real signed paper, kept inside the consent record's sealed part (D55). A photo went
/// through the same pipeline as a treatment photo (resized, metadata stripped) and carries a thumbnail; a file is
/// kept as she chose it. Decrypted only in memory, never written anywhere else.
struct ConsentDocument: Hashable, Codable, Sendable {
    var kind: ConsentDocumentKind
    /// The file's name as she chose it; nil for a photo.
    var fileName: String?
    /// The uniform type identifier ("public.jpeg", "com.adobe.pdf"), so the document opens the way it was stored.
    var contentType: String
    var data: Data
    var thumbnail: Data?

    /// A file (a PDF scan of a few pages) above this is not a consent. A photo goes through the photo pipeline and
    /// ends well below it. The reader and the screen rules both enforce it, so it lives with the model.
    static let maximumBytes = 10 * 1_024 * 1_024
}
