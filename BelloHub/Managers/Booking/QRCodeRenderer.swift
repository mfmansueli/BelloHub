//
//  QRCodeRenderer.swift
//  BelloHub
//

import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Draws a QR code for a text with Core Image. The picture is black on white with a quiet border whatever the
/// appearance: a scanner needs that contrast, so it never follows dark mode.
enum QRCodeRenderer {
    /// A square image of `text`, or nil when it cannot be encoded. `pixelsPerModule` makes the squares crisp: the
    /// picture is built at its final size, not stretched afterwards.
    static func image(for text: String, pixelsPerModule: Int = 10) -> CGImage? {
        guard let data = text.data(using: .utf8), !data.isEmpty else { return nil }
        let generator = CIFilter.qrCodeGenerator()
        generator.message = data
        // M: survives a smudge or a crease on a printed table card without making the code dense.
        generator.correctionLevel = "M"
        guard let output = generator.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: CGFloat(pixelsPerModule),
                                                              y: CGFloat(pixelsPerModule)))
        // The generator draws no quiet zone of its own; four modules of white around it is what the spec asks for.
        let border = CGFloat(4 * pixelsPerModule)
        let white = CIImage(color: .white).cropped(to: scaled.extent.insetBy(dx: -border, dy: -border))
        let composed = scaled.composited(over: white)
        return CIContext().createCGImage(composed, from: composed.extent)
    }
}
