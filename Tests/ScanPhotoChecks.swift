import CoreGraphics
import CoreImage.CIFilterBuiltins
import CoreText
import Foundation

@main
struct ScanPhotoChecks {
    static func main() {
        let payload = "https://example.com/qr/scan-test"
        let width = 900
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)

        guard let canvas = CGContext(
            data: nil, width: width, height: 1_100, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let code = filter.outputImage,
           let qr = CIContext().createCGImage(code, from: code.extent) else {
            fatalError("Could not generate scan fixture")
        }
        canvas.setFillColor(CGColor(gray: 1, alpha: 1))
        canvas.fill(CGRect(x: 0, y: 0, width: 900, height: 1_100))
        canvas.interpolationQuality = .none
        canvas.draw(qr, in: CGRect(x: 276, y: 530, width: 348, height: 348))

        func write(_ value: String, y: CGFloat) {
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica-Bold" as CFString, 66, nil),
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1)
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: value, attributes: attributes))
            let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
            canvas.textPosition = CGPoint(x: (CGFloat(width) - CGFloat(textWidth)) / 2, y: y)
            CTLineDraw(line, canvas)
        }
        write("555AX55", y: 930)
        write("837AY04", y: 400)

        guard let frame = canvas.makeImage() else { fatalError("Missing scan fixture") }
        precondition(ScanPhotoRecovery.busNumber(in: frame, orientation: .up, matching: payload) == "837AY04")
        precondition(ScanPhotoRecovery.busNumber(in: frame, orientation: .up, matching: "different code") == nil)
        print("Still frame checks passed")
    }
}
