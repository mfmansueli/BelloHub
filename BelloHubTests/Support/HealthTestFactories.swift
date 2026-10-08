//
//  HealthTestFactories.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A small health form catalog written inline, so the rule tests do not depend on the shipped files. It has every
/// kind of question, one with a choice that has "None", professions that differ, and one that starts off.
func makeHealthCatalog() -> HealthFormCatalog {
    let json = """
    {"localization": "en", "status": "needs_review", "questions": [
      {"key": "allergies", "kind": "choices", "professions": [], "isOnByDefault": true, "allowsNone": true,
       "name": "Allergies", "prompt": "Do you have any allergies?",
       "options": [{"key": "fragrance", "name": "Fragrance"}, {"key": "latex", "name": "Latex"},
                   {"key": "retinol", "name": "Retinol"}]},
      {"key": "medication", "kind": "yesNo", "professions": [], "isOnByDefault": true,
       "name": "Medication", "prompt": "Do you take any regular medication?"},
      {"key": "pregnancy", "kind": "yesNo", "professions": ["esthetician", "lash"], "isOnByDefault": true,
       "name": "Pregnant or breastfeeding", "prompt": "Are you pregnant or breastfeeding?"},
      {"key": "sunExposure", "kind": "yesNo", "professions": ["esthetician"], "isOnByDefault": false,
       "name": "Sun exposure", "prompt": "Recent sunburn?"},
      {"key": "scalp", "kind": "yesNo", "professions": ["hair"], "isOnByDefault": true,
       "name": "Scalp conditions", "prompt": "Any scalp condition?"},
      {"key": "notes", "kind": "text", "professions": [], "isOnByDefault": true,
       "name": "Anything else", "prompt": "Anything else to know?"}
    ]}
    """
    guard let catalog = try? HealthFormCatalog.decode(Data(json.utf8)) else {
        preconditionFailure("the test health catalog must decode")
    }
    return catalog
}

func makeHealthTemplate(
    version: Int = 1,
    keys: [String] = ["allergies", "medication", "pregnancy", "notes"],
    months: Int = 12,
    createdAt: Date = TestClock.days(-30)
) -> HealthFormTemplate {
    HealthFormTemplate(version: version, questionKeys: keys, reviewEveryMonths: months, createdAt: createdAt)
}

func makeHealthForm(
    clientID: UUID = UUID(),
    version: Int = 1,
    answers: [String: HealthAnswer] = ["allergies": .choices(["fragrance"]), "medication": .no],
    signedAt: Date? = TestClock.days(-10),
    filledBy: HealthFiller = .client,
    isForMinor: Bool = false
) -> HealthForm {
    HealthForm(
        id: UUID(), clientID: clientID, formVersion: version, filledBy: filledBy, isForMinor: isForMinor,
        signedAt: signedAt, importedFromItemID: nil, answers: answers, signatureImage: nil,
        guardianName: isForMinor ? "Rita Costa" : nil, minorName: isForMinor ? "Ana Costa" : nil
    )
}

/// A professional in São Paulo who speaks `localeID`, with the professions she works in.
func makeHealthProfile(
    professions: [ProfessionID] = [.esthetician], localeID: String = "en", name: String = "Maria Silva"
) -> ProfessionalProfile {
    ProfessionalProfile(
        displayName: name, businessName: "Maria Beauty", regionCode: "BR", timeZoneID: "America/Sao_Paulo",
        currencyCode: "BRL", appLocaleID: localeID, professions: professions, createdAt: TestClock.now
    )
}
