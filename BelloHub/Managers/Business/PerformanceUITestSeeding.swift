//
//  PerformanceUITestSeeding.swift
//  BelloHub
//

#if DEBUG
import Foundation
import UIKit

/// Data for the performance budgets of docs/13-TESTING-QUALITY.md section 6, measured by `PerformanceUITests`:
/// `-uiPerfClients 2000` adds that many clients (names, phones, a few tags), `-uiPerfPhotos 200` adds that many photos
/// to the seeded client of `-uiSeed clientWithHealth`, each a distinct 1200 x 1600 JPEG with its thumbnail, as the
/// camera pipeline would store them. DEBUG only; runs after `UITestSeeding` created the professional.
enum PerformanceUITestSeeding {
    static let clientsArgument = "-uiPerfClients"
    static let photosArgument = "-uiPerfPhotos"

    @MainActor
    static func seedIfRequested(
        _ dependencies: AppDependencies, arguments: [String] = ProcessInfo.processInfo.arguments
    ) async {
        guard let repository = dependencies.vault.repository else { return }
        if let count = value(after: clientsArgument, in: arguments) {
            for index in 0..<count {
                let first = firstNames[index % firstNames.count]
                let last = lastNames[(index / 7) % lastNames.count]
                let client = Client(
                    name: "\(first) \(last) \(index)",
                    phoneE164: String(format: "+55119%08d", index), createdAt: Date().addingTimeInterval(-86_400)
                )
                _ = try? await repository.save(client)
            }
        }
        if let count = value(after: photosArgument, in: arguments) {
            let kinds: [PhotoKind] = [.before, .after, .progress]
            for index in 0..<count {
                let photo = Photo(
                    id: UUID(), clientID: UITestSeeding.healthClientID, recordID: nil,
                    takenAt: Date().addingTimeInterval(-Double(index) * 3_600), kind: kinds[index % kinds.count],
                    visibility: .professionalOnly
                )
                try? await repository.save(photo, data: image(number: index))
            }
        }
    }

    private static func value(after flag: String, in arguments: [String]) -> Int? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return Int(arguments[index + 1])
    }

    /// A distinct photo: a tinted gradient with its number, so no two share bytes (as real photos would not).
    private static func image(number: Int) -> PhotoData {
        let hue = CGFloat(number % 36) / 36
        let full = render(size: CGSize(width: 1_200, height: 1_600), hue: hue, number: number)
        let thumbnail = render(size: CGSize(width: 240, height: 320), hue: hue, number: number)
        return PhotoData(image: full.jpegData(compressionQuality: 0.8) ?? Data(),
                         thumbnail: thumbnail.jpegData(compressionQuality: 0.7) ?? Data())
    }

    private static func render(size: CGSize, hue: CGFloat, number: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colors = [UIColor(hue: hue, saturation: 0.4, brightness: 0.9, alpha: 1).cgColor,
                          UIColor(hue: hue, saturation: 0.7, brightness: 0.5, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: nil, colors: colors, locations: nil) {
                context.cgContext.drawLinearGradient(
                    gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: []
                )
            }
            let text = "\(number)" as NSString
            text.draw(at: CGPoint(x: size.width * 0.1, y: size.height * 0.1), withAttributes: [
                .font: UIFont.systemFont(ofSize: size.width / 5), .foregroundColor: UIColor.white
            ])
        }
    }

    private static let firstNames = [
        "Ana", "Bea", "Carla", "Dani", "Eva", "Fernanda", "Gabi", "Helena", "Iris", "Julia"
    ]
    private static let lastNames = ["Costa", "Lima", "Souza", "Rocha", "Alves", "Nunes", "Duarte", "Mendes"]
}
#endif
