//
//  ProductRulesTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("ProductRules")
struct ProductRulesTests {
    private func product(
        _ name: String, brand: String = "", category: ProductCategory = .serum, shared: Bool = false, position: Int = 0
    ) -> Product {
        Product(name: name, brand: brand, category: category, sharedWithClient: shared, position: position)
    }

    private func draft(_ name: String, brand: String = "") -> ProductDraft {
        var draft = ProductDraft()
        draft.name = name
        draft.brand = brand
        return draft
    }

    @Test("A new product is private, as the data model says, and starts as a serum")
    func defaults() {
        let form = ProductDraft()
        #expect(!form.sharedWithClient && form.category == .serum && form.note.isEmpty)
    }

    @Test("The same name from the same brand is taken; from another brand it is not")
    func nameAndBrand() {
        let calming = product("Calming serum", brand: "Acme")
        #expect(ProductRules.nameCheck("calming SERUM", brand: "acme", among: [calming]) == .duplicate)
        func check(_ name: String, brand: String, editing id: UUID? = nil) -> CatalogNameCheck {
            ProductRules.nameCheck(name, brand: brand, among: [calming], editing: id)
        }
        #expect(check("Calming serum", brand: "Beta").acceptedName == "Calming serum")
        #expect(check("Calming serum", brand: "").acceptedName == "Calming serum")
        #expect(check("calming serum", brand: "Acme", editing: calming.id).acceptedName != nil,
                "the product being edited does not clash with itself")
    }

    @Test("Two products with no brand and the same name are the same product")
    func noBrand() {
        #expect(ProductRules.nameCheck("Gentle cleanser", brand: "", among: [product("Gentle cleanser")]) == .duplicate)
    }

    @Test("Issues name what is wrong")
    func issues() {
        #expect(ProductRules.issues(in: draft(""), among: []) == [.nameEmpty])
        #expect(ProductRules.issues(in: draft(String(repeating: "x", count: 61)), among: []) == [.nameTooLong])
        let longBrand = draft("Serum", brand: String(repeating: "b", count: 61))
        #expect(ProductRules.issues(in: longBrand, among: []) == [.brandTooLong])
        var note = draft("Serum")
        note.note = String(repeating: "n", count: 201)
        #expect(ProductRules.issues(in: note, among: []) == [.noteTooLong])
        #expect(ProductRules.issues(in: draft("Serum"), among: [product("Serum")]) == [.nameTaken])
    }

    @Test("Building cleans the text and places a new product after the last")
    func building() throws {
        var form = draft("  Calming   serum ", brand: " Acme  Labs ")
        form.category = .moisturizer
        form.note = "  Fragrance-free \n"
        form.sharedWithClient = true
        let id = UUID()

        let built = try #require(ProductRules.build(form, among: [product("A", position: 2)], makeID: { id }))

        #expect(built.id == id && built.position == 3)
        #expect(built.name == "Calming serum" && built.brand == "Acme Labs" && built.note == "Fragrance-free")
        #expect(built.category == .moisturizer && built.sharedWithClient)
    }

    @Test("Editing keeps the id and place")
    func editing() throws {
        let existing = product("Cream", position: 5)
        let built = try #require(ProductRules.build(draft("Cream 2"), among: [existing], editing: existing))
        #expect(built.id == existing.id && built.position == 5)
    }

    @Test("A product becomes a form and back without losing anything")
    func roundTrip() throws {
        let original = Product(
            id: UUID(), name: "Sun cream", brand: "Acme", category: .sunCare, note: "SPF 50", sharedWithClient: true,
            position: 1
        )
        let rebuilt = try #require(ProductRules.build(ProductDraft(original), among: [original], editing: original))
        #expect(rebuilt == original)
    }

    @Test("The share switch changes only the share setting")
    func sharing() {
        let calming = product("Calming", brand: "Acme", position: 3)
        let shared = ProductRules.setting(calming, shared: true)
        #expect(shared.sharedWithClient && shared.name == "Calming" && shared.position == 3 && shared.brand == "Acme")
    }

    @Test("The line under a name joins the brand and the kind, and leaves out what is missing")
    func details() {
        #expect(ProductRules.details(brand: "Acme", category: "Serum") == "Acme · Serum")
        #expect(ProductRules.details(brand: "  ", category: "Serum") == "Serum")
        #expect(ProductRules.details(brand: "Acme", category: "") == "Acme")
    }

    @Test("The list is in order by position, then name")
    func ordering() {
        let list = [product("B", position: 1), product("A", position: 1), product("C", position: 0)]
        #expect(ProductRules.ordered(list).map(\.name) == ["C", "A", "B"])
    }

    @Test("An unknown product kind from a newer version reads as other and is never lost")
    func unknownKind() throws {
        let json = Data("""
        {"id": "\(UUID().uuidString)", "name": "Mask", "brand": "", "category": "futureKind", "note": "",
         "sharedWithClient": false, "position": 0}
        """.utf8)
        let decoded = try JSONDecoder().decode(Product.self, from: json)
        #expect(decoded.category == .other)
    }
}
