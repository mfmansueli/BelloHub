//
//  FirestoreClient.swift
//  BelloHub
//

import Foundation

/// The documents the owner may read directly (firebase/functions/API.md section 8), without the Firestore SDK: the
/// REST API with her ID token answers under the same security rules. Each document comes back as plain JSON bytes
/// (Firestore's typed values unwrapped by `FirestoreDocumentDecoder`) with the document id under `"id"`, so the models
/// decode with `CallableJSON.decoder` like a function result. Throws `ServerError`.
protocol FirestoreClient: Sendable {
    /// Documents of a top-level collection whose `ownerField` equals `uid`, optionally only those whose `since.field`
    /// is at or after `since.date`, ordered by that field. At most `limit`.
    func query(
        collection: String, ownerField: String, uid: String, since: FirestoreSince?, limit: Int
    ) async throws -> [Data]
    /// Every document under `path` (a collection path such as `inbox/<uid>/items`), at most `limit`.
    func list(path: String, limit: Int) async throws -> [Data]
}
