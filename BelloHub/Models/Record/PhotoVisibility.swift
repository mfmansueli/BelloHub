//
//  PhotoVisibility.swift
//  BelloHub
//

/// Who may see a photo. Private by default; sharing needs the client's consent (D2, `ConsentRecord` kind photos).
enum PhotoVisibility: String, PersistedEnum {
    case professionalOnly
    case shareWithClient
    case portfolio

    /// An unknown value must never widen who sees a photo.
    static let fallback = PhotoVisibility.professionalOnly
}
