//
//  LegalTextValues.swift
//  BelloHub
//

import Foundation

/// What fills the `{{PLACEHOLDERS}}` of a legal notice. The operator fields come from the owner's configuration,
/// which does not exist yet (human task H17), so they are nil until then and render as pending.
struct LegalTextValues: Equatable, Sendable {
    var operatorName: String?
    var operatorEmail: String?
    var operatorAddress: String?
    var webBaseURL: String?
    var effectiveDate: String?

    init(
        operatorName: String? = nil, operatorEmail: String? = nil, operatorAddress: String? = nil,
        webBaseURL: String? = nil, effectiveDate: String? = nil
    ) {
        self.operatorName = operatorName
        self.operatorEmail = operatorEmail
        self.operatorAddress = operatorAddress
        self.webBaseURL = webBaseURL
        self.effectiveDate = effectiveDate
    }

    /// The value of a placeholder name (`OPERATOR_NAME`), or nil when it is unknown or not filled in.
    func value(for placeholder: String) -> String? {
        let found: String? = switch placeholder {
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
