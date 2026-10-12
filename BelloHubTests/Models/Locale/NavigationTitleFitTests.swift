//
//  NavigationTitleFitTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing
import UIKit

/// Every navigation title fits its bar in every localization (S11). The system truncates a title that does not fit
/// ("Pedido de agendamen…" on 2.10 in pt-BR) and the accessibility audit does not report it, so the widths are
/// measured here with the bar's own fonts: a large title (34 pt bold) must fit the width of the smallest supported
/// iPhone minus its margins (375 − 2 × 16 pt), an inline title (17 pt semibold) the space a back button leaves.
/// The lists follow the screens: `scripts/check-strings.sh` fails when a `.navigationTitle` key in `Screens/` is
/// missing here or sits in the wrong list for its display mode.
@Suite("Navigation titles")
struct NavigationTitleFitTests {
    static let largeTitleWidth: CGFloat = 343
    static let inlineTitleWidth: CGFloat = 250

    /// Screens whose title is large (explicitly, or by default in their navigation stack).
    static let largeTitleKeys = [
        "account.title", "addOns.title", "aiSettings.title", "availability.title", "followUpQueue.title",
        "integrations.title", "languageRegion.title", "main.tab.alerts", "main.tab.calendar", "main.tab.more",
        "notificationSettings.title", "plan.title", "products.title", "quickReplies.title", "recordTemplate.title",
        "services.title", "shareLink.title", "tags.title", "team.title", "waitlist.title", "weekGlance.title"
    ]

    /// Screens and sheets with an inline title.
    static let inlineTitleKeys = [
        "account.delete.title", "addOns.editor.addTitle", "addOns.editor.editTitle", "appointment.title",
        "availability.breakSheet.addTitle", "availability.breakSheet.editTitle", "availability.dayOffSheet.addTitle",
        "availability.dayOffSheet.editTitle", "beforeYouStart.title", "blockTime.title",
        "bookingRequest.suggest.title", "bookingRequest.title",
        "bookingSettings.pauseSheet.title", "bookingSettings.title", "cancelAppointment.title", "cancelPolicy.title",
        "workplace.title",
        "clientKnowledge.title", "clientMerge.title", "credentials.preview.title", "credentials.title",
        "export.title", "exportRecord.title", "fieldEditor.addTitle", "fieldEditor.editTitle", "formTemplates.title",
        "health.title", "help.title", "home.title", "incident.title", "newAppointment.title", "noShowHistory.title",
        "noShowMark.title", "noShowPolicy.title", "onb.service.title", "onb.terminology.addTitle", "privacy.title",
        "products.editor.addTitle", "products.editor.editTitle", "quickReplies.editor.addTitle",
        "quickReplies.editor.editTitle", "recordHistory.correction.title", "recordHistory.edit.title",
        "recordHistory.photo.title", "recordHistory.title", "recoveryKey.title", "reschedule.title",
        "rescheduleRequest.title", "restoreKey.title", "runningLate.title", "services.contra.title",
        "services.editor.addTitle", "services.editor.editTitle", "sessionPlan.title", "tags.editor.addTitle",
        "tags.editor.editTitle", "treatmentFlow.form.title", "treatmentFlow.register.title",
        "visitDetail.title", "reuseVisit.title", "visitDay.title", "organizePhotos.title", "photoCompare.title",
        "personalization.title", "clientPicker.title"
    ]

    @Test("Large titles fit at 34 pt in every localization", arguments: AppLocalization.allCases)
    func largeTitles(localization: AppLocalization) {
        let font = UIFont.systemFont(ofSize: 34, weight: .bold)
        for key in Self.largeTitleKeys {
            let text = Self.text(key, in: localization)
            #expect(Self.width(text, font) <= Self.largeTitleWidth, "\(key) in \(localization.rawValue): \(text)")
        }
        // The Clients tab and screen are titled with the word she chose for the people she serves.
        for term in ClientTerm.allCases {
            let text = term.titlePlural(in: localization.locale)
            #expect(Self.width(text, font) <= Self.largeTitleWidth, "\(term) in \(localization.rawValue): \(text)")
        }
    }

    @Test("Inline titles fit at 17 pt in every localization", arguments: AppLocalization.allCases)
    func inlineTitles(localization: AppLocalization) {
        let font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        for key in Self.inlineTitleKeys {
            let text = Self.text(key, in: localization)
            #expect(Self.width(text, font) <= Self.inlineTitleWidth, "\(key) in \(localization.rawValue): \(text)")
        }
    }

    private static func text(_ key: String, in localization: AppLocalization) -> String {
        var resource = LocalizedStringResource(String.LocalizationValue(key))
        resource.locale = localization.locale
        return String(localized: resource)
    }

    private static func width(_ text: String, _ font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
