import CoreImage.CIFilterBuiltins
import UIKit

nonisolated enum QRCode {
    /// A QR code for the link at one pixel a module, to be drawn without
    /// smoothing. Share links are short, so medium error correction still
    /// leaves a sparse code that survives a photo of a screen.
    static func image(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
            let image = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: image)
    }
}
