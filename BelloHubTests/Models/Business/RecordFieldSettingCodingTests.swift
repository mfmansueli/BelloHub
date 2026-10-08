//
//  RecordFieldSettingCodingTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

/// What S3 saved must still read after the field gained a kind, options and a unit: the vault stores the template as
/// JSON and an upgrade never rewrites it.
@Suite("RecordFieldSetting coding")
struct RecordFieldSettingCodingTests {
    /// A record template exactly as the S3 build stored it (`VaultCoding`: sorted keys, dates as seconds), with fields
    /// that have no `kind`, `options` or `unit`, and no `customName` for the catalog's fields.
    private static let s3Template = """
    {"fields":[
      {"isOn":true,"key":"est.skin","profession":"esthetician"},
      {"isOn":false,"key":"est.technique","profession":"esthetician"},
      {"customName":"Mood","isOn":true,"key":"custom-1","profession":"esthetician"}],
     "id":"B3110000-0000-4000-8000-000000000002",
     "intake":[{"isOn":true,"item":"healthHistory","profession":"esthetician"}],
     "updatedAt":781000000.5}
    """

    private func decode(_ json: String) throws -> RecordTemplate {
        try VaultCoding.merge(RecordTemplate.self, plain: Data(json.utf8), sensitive: nil)
    }

    @Test("A template saved by the S3 build reads back, every field as free text")
    func decodesTheS3Shape() throws {
        let template = try decode(Self.s3Template)

        #expect(template.id == RecordTemplate.singletonID)
        #expect(template.fields.map(\.key) == ["est.skin", "est.technique", "custom-1"])
        #expect(template.fields.map(\.isOn) == [true, false, true])
        #expect(template.fields.allSatisfy { $0.kind == .text && $0.options.isEmpty && $0.unit == nil })
        #expect(template.fields[2].customName == "Mood" && template.fields[2].isCustom)
        #expect(!template.fields[0].isCustom)
        #expect(template.intake == [IntakeSetting(profession: .esthetician, item: .healthHistory, isOn: true)])
        #expect(template.updatedAt == Date(timeIntervalSinceReferenceDate: 781_000_000.5))
    }

    @Test("A field with a kind, options and a unit survives the vault's coding")
    func roundTripsTheNewShape() throws {
        let fields = [
            RecordFieldSetting(
                profession: .hair, key: "custom-a", customName: "Finish", isOn: true, kind: .choice,
                options: ["Matte", "Dewy", "Satin"]
            ),
            RecordFieldSetting(
                profession: .hair, key: "custom-b", customName: "Length", isOn: false, kind: .number, unit: "mm"
            ),
            RecordFieldSetting(profession: .hair, key: "custom-c", customName: "Patch test", isOn: true, kind: .yesNo)
        ]
        let template = RecordTemplate(fields: fields, intake: [], updatedAt: TestClock.now)

        let (plain, sensitive) = try VaultCoding.split(template)
        let decoded = try VaultCoding.merge(RecordTemplate.self, plain: plain, sensitive: sensitive)

        #expect(decoded == template)
        #expect(decoded.fields[0].options == ["Matte", "Dewy", "Satin"])
        #expect(decoded.fields[1].unit == "mm")
    }

    @Test("A kind this version does not know reads as free text, so what was written stays readable")
    func unknownKindFallsBack() throws {
        let json = """
        {"isOn":true,"key":"custom-z","customName":"Signature","kind":"drawing","profession":"tattoo"}
        """

        let field = try JSONDecoder().decode(RecordFieldSetting.self, from: Data(json.utf8))

        #expect(field.kind == .text)
        #expect(field.key == "custom-z" && field.customName == "Signature")
    }

    @Test("Extra keys from a newer version are ignored")
    func ignoresUnknownKeys() throws {
        let json = """
        {"isOn":true,"key":"est.skin","profession":"esthetician","helpText":"later","kind":"text"}
        """
        let field = try JSONDecoder().decode(RecordFieldSetting.self, from: Data(json.utf8))
        #expect(field.key == "est.skin" && field.kind == .text)
    }

    @Test("A field without a profession or a key is not a field")
    func requiresTheOriginalKeys() {
        let json = #"{"isOn":true,"key":"est.skin"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(RecordFieldSetting.self, from: Data(json.utf8))
        }
    }

    @Test("Counting switched-on fields covers only the professions she has")
    func fieldCounts() throws {
        let template = try decode(Self.s3Template)
        #expect(template.fieldCounts(for: [.esthetician]) == (on: 2, total: 3))
        #expect(template.fieldCounts(for: [.hair]) == (on: 0, total: 0))
        #expect(template.fieldCounts(for: []) == (on: 0, total: 0))
    }
}
