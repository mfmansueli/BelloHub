//
//  TestCatalog.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation

/// A small profession catalog written inline, so tests do not depend on the shipped files. The "shared" service
/// appears under two professions with the same key, to test that choosing both lists it once.
func makeCatalog() -> ProfessionCatalog {
    let json = """
    {"localization": "en", "status": "needs_review", "professions": [
      {"id": "esthetician", "name": "Esthetician", "plural": "estheticians",
       "services": [
         {"key": "est.glow", "name": "Glow Facial", "category": "Facial", "minutes": 60, "followUpWeeks": 4,
          "selected": true, "photos": true},
         {"key": "est.peel", "name": "Chemical Peel", "category": "Facial", "minutes": 45, "followUpWeeks": null,
          "selected": false, "photos": false},
         {"key": "shared.consult", "name": "Consultation", "category": "General", "minutes": 30,
          "followUpWeeks": null, "selected": true, "photos": false}],
       "tags": [
         {"key": "est.vip", "name": "VIP", "color": "rose", "selected": false},
         {"key": "est.sensitive", "name": "Sensitive Skin", "color": "sage", "selected": true}],
       "fields": [
         {"key": "est.skin", "name": "Skin condition", "on": true},
         {"key": "est.technique", "name": "Technique", "on": false}],
       "intake": ["healthHistory", "consentForm"]},
      {"id": "hair", "name": "Hair stylist", "plural": "hair stylists",
       "services": [
         {"key": "hair.cut", "name": "Haircut", "category": "Hair", "minutes": 45, "followUpWeeks": 6,
          "selected": true, "photos": false},
         {"key": "shared.consult", "name": "Consultation", "category": "General", "minutes": 30,
          "followUpWeeks": null, "selected": true, "photos": false}],
       "tags": [{"key": "hair.blonde", "name": "Blonde", "color": "sand", "selected": true}],
       "fields": [{"key": "hair.formula", "name": "Formula", "on": true}],
       "intake": ["patchTestLog"]},
      {"id": "other", "name": "Other", "plural": "professionals",
       "services": [{"key": "other.session", "name": "Session", "category": "Services", "minutes": 60,
                     "followUpWeeks": null, "selected": true, "photos": false}],
       "tags": [{"key": "other.vip", "name": "VIP", "color": "rose", "selected": false}],
       "fields": [{"key": "other.notes", "name": "Notes", "on": true}],
       "intake": []}
    ]}
    """
    guard let catalog = try? ProfessionCatalog.decode(Data(json.utf8)) else {
        preconditionFailure("the test catalog must decode")
    }
    return catalog
}

func makeDraft(
    professions: [ProfessionID] = [.esthetician], name: String = "Maria Silva", localization: AppLocalization = .en
) -> OnboardingDraft {
    let regions = (try? RegionCatalog.loadBundled()) ?? RegionCatalog(presets: [])
    var draft = OnboardingDraft.initial(
        regions: regions, deviceRegion: "BR", languageCode: "pt", preferredLanguages: ["pt-BR"],
        deviceTimeZoneID: "America/Sao_Paulo"
    )
    draft.displayName = name
    draft.localization = localization
    draft.professions = professions
    return draft
}
