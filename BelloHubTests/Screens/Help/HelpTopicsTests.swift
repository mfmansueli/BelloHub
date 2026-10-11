//
//  HelpTopicsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("HelpTopics")
struct HelpTopicsTests {
    @Test("Every topic has a question and an answer in the catalog, in English and in Arabic")
    func topicsAreLocalized() throws {
        #expect(HelpTopics.topics.count == 6)
        let english = try localizedBundle("en")
        let arabic = try localizedBundle("ar")
        for topic in HelpTopics.topics {
            for key in [topic.questionKey, topic.answerKey] {
                let englishText = english.localizedString(forKey: key, value: key, table: nil)
                let arabicText = arabic.localizedString(forKey: key, value: key, table: nil)
                #expect(englishText != key, "\(key)")
                #expect(arabicText != key && arabicText != englishText, "\(key)")
            }
        }
    }

    private func localizedBundle(_ localization: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: localization, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test("The support mail link carries the subject and never a body")
    func mailURL() throws {
        let url = try #require(HelpTopics.mailURL(subject: "Bello Hub support"))
        #expect(url.scheme == "mailto")
        #expect(url.absoluteString.hasPrefix("mailto:support@bellohub.app?subject="))
        #expect(url.absoluteString.contains("Bello%20Hub%20support"))
        #expect(!url.absoluteString.contains("body="))
    }
}
