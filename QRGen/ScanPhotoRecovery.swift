import ImageIO
import Vision

enum ScanPhotoRecovery {
    static func busNumber(in image: CGImage, orientation: CGImagePropertyOrientation, matching payload: String) -> String? {
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        let barcodes = VNDetectBarcodesRequest()
        barcodes.symbologies = [.qr]
        do {
            try handler.perform([barcodes])
            let matching = (barcodes.results ?? []).filter { $0.payloadStringValue == payload }
            guard matching.count == 1, let qr = matching.first?.boundingBox else { return nil }

            // Vision's normalized coordinates grow upward, so the printed number is below minY.
            let area = CGRect(
                x: qr.midX - qr.width * 0.95,
                y: qr.minY - qr.height * 1.50,
                width: qr.width * 1.90,
                height: qr.height * 1.50
            ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !area.isNull, area.width > 0, area.height > 0 else { return nil }

            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.recognitionLanguages = ["en-US"]
            text.usesLanguageCorrection = false
            text.regionOfInterest = area
            try handler.perform([text])
            let numbers = Set((text.results ?? []).compactMap { observation in
                observation.topCandidates(1).first.flatMap { findBusNumber(in: $0.string) }
            })
            return numbers.count == 1 ? numbers.first : nil
        } catch {
            return nil
        }
    }
}
