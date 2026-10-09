//
//  CatalogUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation

/// What `-uiCatalog` adds to the vault before the app starts: two more services (one with every setting on, one
/// switched off), four add-ons, three products, three credentials and a registration number, so the audit of the
/// business screens walks full screens and not empty ones. It goes straight to the vault and does not depend on
/// `-uiSeed`; the services take the places after the two the setup saves. DEBUG only.
enum CatalogUITestSeeding {
    static let argument = "-uiCatalog"

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard arguments.contains(argument), let repository = dependencies.vault.repository else { return }
        let services = [
            Service(
                name: "Protocol 360", category: "Protocol", durationMinutes: 120, priceDisplay: .onRequest,
                followUpWeeks: 6, remindBeforeAfterPhotos: true, aftercareTemplate: "",
                position: 2, contraindications: ["pregnancy", "allergies.latex", "minor"], requiresPatchTest: true
            ),
            Service(
                name: "Chemical Peel", category: "Facial", durationMinutes: 45, priceAmount: 90,
                priceDisplay: .startingFrom, isActive: false, position: 3
            )
        ]
        let addOns = [("Eyebrow tint", 15, 20, true), ("LED light", 15, 25, true),
                      ("Hand and arm massage", 10, 15, true), ("Extractions", 20, 30, false)]
            .enumerated().map { index, item in
                AddOn(
                    id: UUID(), name: item.0, minutes: item.1, priceAmount: Decimal(item.2), isOffered: item.3,
                    position: index
                )
            }
        let products = [
            Product(name: "Calming serum", brand: "Acme", category: .serum, sharedWithClient: true, position: 0),
            Product(name: "Fragrance-free barrier cream", category: .moisturizer, position: 1),
            Product(name: "Gentle cleanser", category: .cleanser, sharedWithClient: true, position: 2)
        ]
        let credentials = [
            Credential(title: "Aesthetics technical course", institution: "Senac SP", year: 2019, position: 0),
            Credential(title: "Dermaplaning certification", year: 2022, position: 1),
            Credential(title: "Biosafety training", year: 2024, position: 2),
            Credential(kind: .registration, title: "", registrationNumber: "COREN 123456", position: 3)
        ]
        try? await repository.save(services)
        try? await repository.save(addOns)
        try? await repository.save(products)
        try? await repository.save(credentials)
    }
}
#endif
