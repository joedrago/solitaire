import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

// Renders a string as a QR code Image via CoreImage (no third-party dep). Used
// to show the current seed bottom-right so a deal can be scanned and shared
// phone-to-phone.
//
// The data modules are emitted black-on-transparent (CIFalseColor maps the
// light squares to clear), so the caller can paint whatever "paper" color
// behind it — letting dark mode tint the field reactively (white / dim gray /
// warm) without regenerating the code. The modules stay black for contrast, so
// it remains scannable under every treatment. The image is one pixel per
// module; scale it up with .interpolation(.none) to keep the squares crisp.
enum QRCode {
    private static let context = CIContext()

    static func image(_ string: String) -> Image? {
        let qr = CIFilter.qrCodeGenerator()
        qr.message = Data(string.utf8)
        qr.correctionLevel = "M"
        guard let base = qr.outputImage else {
            return nil
        }

        let falseColor = CIFilter.falseColor()
        falseColor.inputImage = base
        falseColor.color0 = CIColor.black // dark squares -> opaque black modules
        falseColor.color1 = CIColor(red: 0, green: 0, blue: 0, alpha: 0) // light squares -> clear

        guard let output = falseColor.outputImage,
              let cg = context.createCGImage(output, from: output.extent)
        else {
            return nil
        }
        return Image(decorative: cg, scale: 1.0)
    }
}
