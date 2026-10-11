//
//  BookingSlugTests.swift
//  BelloHubTests
//

@testable import BelloHub
import Foundation
import Testing

@Suite("BookingSlug")
struct BookingSlugTests {
    // MARK: - Validation (the server's SlugSchema)

    @Test("Valid addresses pass", arguments: ["maria", "maria-silva", "abc", "a1b2", "maria-beauty-studio-2026"])
    func validSlugs(slug: String) {
        #expect(BookingSlug.validate(slug) == nil)
    }

    @Test("The length is 3 to 30 characters")
    func lengthBounds() {
        #expect(BookingSlug.validate("ab") == .tooShort)
        #expect(BookingSlug.validate("abc") == nil)
        #expect(BookingSlug.validate(String(repeating: "a", count: 30)) == nil)
        #expect(BookingSlug.validate(String(repeating: "a", count: 31)) == .tooLong)
        #expect(BookingSlug.validate("") == .tooShort)
    }

    @Test("Only a to z, 0 to 9 and hyphens", arguments: ["Maria", "ma ria", "maría", "ma_ria", "ma.ria", "ماريا",
        "maria!"])
    func badCharacters(slug: String) {
        #expect(BookingSlug.validate(slug) == .characters)
    }

    @Test("No hyphen at either end or two in a row")
    func hyphens() {
        #expect(BookingSlug.validate("-maria") == .hyphenEdges)
        #expect(BookingSlug.validate("maria-") == .hyphenEdges)
        #expect(BookingSlug.validate("ma--ria") == .doubleHyphen)
    }

    @Test("The web app's own routes are reserved", arguments: Array(BookingSlug.reserved.filter { $0.count >= 3 }))
    func reservedWords(slug: String) {
        #expect(BookingSlug.validate(slug) == .reserved)
    }

    @Test("The reserved list is the server's")
    func reservedMatchesServer() {
        let server: Set<String> = [
            "m", "p", "api", "admin", "app", "www", "help", "support", "static", "assets", "login", "auth", "bookings",
            "book", "status", "privacy", "terms", "legal", "about"
        ]
        #expect(BookingSlug.reserved == server)
    }

    // MARK: - Making one from a name

    @Test("Accents are folded and spaces become hyphens")
    func diacritics() {
        #expect(BookingSlug.make(from: "María José Çelik") == "maria-jose-celik")
        #expect(BookingSlug.make(from: "Bärbel Müller-Schön") == "barbel-muller-schon")
        #expect(BookingSlug.make(from: "  Studio   da   Ana  ") == "studio-da-ana")
    }

    @Test("Names in other scripts are read as Latin", arguments: ["ماريا", "मारिया", "Мария", "μαρία", "マリア"])
    func nonLatinNames(name: String) throws {
        let slug = try #require(BookingSlug.make(from: name))
        #expect(BookingSlug.validate(slug) == nil, "\(name) became \(slug)")
    }

    @Test("A known reading of a Cyrillic and a Devanagari name")
    func knownReadings() {
        #expect(BookingSlug.make(from: "Мария") == "mariia" || BookingSlug.make(from: "Мария") == "maria")
        #expect(BookingSlug.make(from: "मारिया")?.hasPrefix("mari") == true)
    }

    @Test("A long name is cut to 30 characters without a hyphen at the end")
    func longNames() throws {
        let slug = try #require(BookingSlug.make(from: "Maria Fernanda de Albuquerque Cavalcanti Studio Beleza"))
        #expect(slug.count <= 30)
        #expect(!slug.hasSuffix("-"))
        #expect(BookingSlug.validate(slug) == nil)
        #expect(slug.hasPrefix("maria-fernanda-de-albuquerque"))
    }

    @Test("A very short name gets a neutral word so it is still valid")
    func shortNames() {
        #expect(BookingSlug.make(from: "Al") == "al-studio")
        #expect(BookingSlug.make(from: "Li") == "li-studio")
    }

    @Test("A name with nothing to read gives nothing")
    func unreadable() {
        #expect(BookingSlug.make(from: "") == nil)
        #expect(BookingSlug.make(from: "   ") == nil)
        #expect(BookingSlug.make(from: "!!!") == nil)
    }

    @Test("A name that is a reserved word is not suggested")
    func reservedNames() {
        #expect(BookingSlug.make(from: "Admin") == nil)
        #expect(BookingSlug.make(from: "Book") == nil)
    }

    // MARK: - While typing

    @Test("Typing is cleaned as it goes and keeps a trailing hyphen")
    func typing() {
        #expect(BookingSlug.sanitizedWhileTyping("Maria ") == "maria-")
        #expect(BookingSlug.sanitizedWhileTyping("Maria Si") == "maria-si")
        #expect(BookingSlug.sanitizedWhileTyping("  ") == "")
        #expect(BookingSlug.sanitizedWhileTyping("-maria") == "maria")
        #expect(BookingSlug.sanitizedWhileTyping("ma  ria") == "ma-ria")
        #expect(BookingSlug.sanitizedWhileTyping(String(repeating: "a", count: 50)).count == 30)
    }

    // MARK: - Suggestions

    @Test("Suggestions are her business name, her name and both, without repeats")
    func suggestions() {
        let result = BookingSlug.suggestions(displayName: "Maria Silva", businessName: "Maria Beauty")
        #expect(result == ["maria-beauty", "maria-silva", "maria-silva-maria-beauty"])
        #expect(BookingSlug.suggestions(displayName: "Maria Silva", businessName: "") == ["maria-silva"])
    }

    @Test("With nothing to build from there is still one valid suggestion")
    func fallbackSuggestion() {
        let result = BookingSlug.suggestions(displayName: "", businessName: "", fallbackSeed: 42)
        #expect(result.count == 1)
        #expect(BookingSlug.validate(result[0]) == nil)
    }
}
