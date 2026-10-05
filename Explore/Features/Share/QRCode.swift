import CoreImage.CIFilterBuiltins
import UIKit

nonisolated enum QRCode {
    /// A QR code for the link at one pixel a module, to be drawn without
    /// smoothing. Share cards are clean images, so the lowest error
    /// correction keeps the code as sparse as it can be.
    static func image(for url: URL) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "L"
        guard let output = filter.outputImage,
            let image = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: image)
    }
}
