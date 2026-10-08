//
//  ConsentKind+LegalDocument.swift
//  BelloHub
//

extension ConsentKind {
    /// The text a consent of this kind is signed on. The one place that knows which document goes with which kind.
    var legalDocument: LegalDocument {
        switch self {
        case .treatment: .consentHealth
        case .photos: .consentPhoto
        case .guardian: .consentGuardian
        }
    }
}
