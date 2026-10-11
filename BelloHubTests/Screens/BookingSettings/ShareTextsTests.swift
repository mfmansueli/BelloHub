//
//  ShareTextsTests.swift
//  BelloHubTests
//

@testable import BelloHub
import CoreImage
import Foundation
import Testing

@Suite("ShareTexts and the QR code")
struct ShareTextsTests {
    private func texts(_ localization: AppLocalization) -> ShareTexts {
        ShareTexts(
            localization: localization, professionalName: "Maria", displayLink: "bellohub.app/maria",
            messageLink: "https://bellohub.app/maria"
        )
    }

    @Test("The English texts")
    func english() {
        let english = texts(.en)
        #expect(english.instagramBio == "Book with me: bellohub.app/maria")
        // The chat greeting carries the full address on its own line (ClientLinkText); the bio keeps the short one.
        #expect(english.whatsAppGreeting
            == "Hi! Thanks for your message. You can book with Maria here:\nhttps://bellohub.app/maria")
        #expect(english.shareMessage == "Book with Maria")
        #expect(english.qrCaption == "Scan to book with Maria")
        #expect(english.cardTitle == "Book with Maria")
        #expect(english.cardSubtitle == "Point your camera at the code")
    }

    @Test("Every text exists in every localization with the name and the link in it",
        arguments: AppLocalization.allCases)
    func everyLocalization(localization: AppLocalization) {
        let shared = texts(localization)
        for text in [shared.instagramBio, shared.whatsAppGreeting] {
            #expect(text.contains("bellohub.app/maria"), "\(localization.rawValue): \(text)")
            #expect(!text.contains("shareLink") && !text.contains("%"))
        }
        #expect(shared.whatsAppGreeting.hasSuffix("\nhttps://bellohub.app/maria"), "\(localization.rawValue)")
        for text in [shared.whatsAppGreeting, shared.shareMessage, shared.qrCaption, shared.cardTitle] {
            #expect(text.contains("Maria"), "\(localization.rawValue): \(text)")
        }
        #expect(!shared.cardSubtitle.isEmpty && !shared.cardSubtitle.contains("shareLink"))
    }

    @Test("In Arabic the name is isolated; the chat link stands alone on its line, the bio link is isolated")
    func bidi() {
        let arabic = texts(.ar)
        #expect(arabic.whatsAppGreeting.contains("\u{2068}Maria\u{2069}"))
        #expect(arabic.whatsAppGreeting.hasSuffix("\nhttps://bellohub.app/maria"))
        #expect(arabic.instagramBio.contains("\u{2066}bellohub.app/maria\u{2069}"))
    }

    // MARK: - QR code

    /// Reads a QR code back from its picture, the way a phone camera would.
    private func decode(_ image: CGImage) -> String? {
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: CIImage(cgImage: image)) ?? []
        return (features.first as? CIQRCodeFeature)?.messageString
    }

    @Test("The QR code reads back as the link", arguments: [
        "https://bellohub.app/maria", "https://bellohub.app/maria-silva-studio", "https://staging.bellohub.app/a1b"
    ])
    func roundTrip(text: String) throws {
        let image = try #require(QRCodeRenderer.image(for: text))
        #expect(decode(image) == text)
    }

    @Test("The picture is square, crisp and bigger than the code itself, with a quiet border")
    func shape() throws {
        let image = try #require(QRCodeRenderer.image(for: "https://bellohub.app/maria", pixelsPerModule: 8))
        #expect(image.width == image.height && image.width > 8 * 21)
        #expect(image.width % 8 == 0, "a whole number of pixels per module")
    }

    @Test("Different links give different pictures; nothing gives nothing")
    func differs() throws {
        let one = try #require(QRCodeRenderer.image(for: "https://bellohub.app/maria"))
        let two = try #require(QRCodeRenderer.image(for: "https://bellohub.app/mario"))
        #expect(one.dataProvider?.data as Data? != two.dataProvider?.data as Data?)
        #expect(QRCodeRenderer.image(for: "") == nil)
    }
}
