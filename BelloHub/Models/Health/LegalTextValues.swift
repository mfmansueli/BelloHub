//
//  LegalTextValues.swift
//  BelloHub
//

import Foundation

/// What fills the `{{PLACEHOLDERS}}` of a legal text. The professional's name comes from her profile; the operator
/// fields come from the owner's configuration, which does not exist yet (human task H17), so they are nil until then.
struct LegalTextValues: Equatable, Sendable {
    var professionalName: String?
    var operatorName: String?
    var operatorEmail: String?
    var operatorAddress: String?
    var webBaseURL: String?
    var effectiveDate: String?

    init(
        professionalName: String? = nil, operatorName: String? = nil, operatorEmail: String? = nil,
        operatorAddress: String? = nil, webBaseURL: String? = nil, effectiveDate: String? = nil
    ) {
        self.professionalName = professionalName
        self.operatorName = operatorName
        self.operatorEmail = operatorEmail
        self.operatorAddress = operatorAddress
        self.webBaseURL = webBaseURL
        self.effectiveDate = effectiveDate
    }

    /// What the app can fill today: the professional's name from her profile. The operator fields wait for the
    /// owner's configuration (H17) and stay pending.
    init(profile: ProfessionalProfile?) {
        self.init(professionalName: profile?.publicName)
    }

    /// The value of a placeholder name (`PROFESSIONAL_NAME`), or nil when it is unknown or not filled in.
    func value(for placeholder: String) -> String? {
        let found: String? = switch placeholder {
        case "PROFESSIONAL_NAME": professionalName
        case "OPERATOR_NAME": operatorName
        case "OPERATOR_EMAIL": operatorEmail
        case "OPERATOR_ADDRESS": operatorAddress
        case "WEB_BASE_URL": webBaseURL
        case "EFFECTIVE_DATE": effectiveDate
        default: nil
        }
        guard let found, !found.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return found
    }
}
