import AVFoundation
import ImageIO
import SwiftUI
import VisionKit

struct ScannerSheet: View {
    var onScan: (ScanReading) -> Void
    var onError: (String) -> Void

    @State private var detected: ScanReading?
    @State private var torchOn = false
    @State private var finished = false
    private let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)

    var body: some View {
        QRScannerView(
            onDetected: { detected = $0 },
            onScan: finish,
            onError: { message in
                guard !finished else { return }
                finished = true
                onError(message)
            }
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            if camera?.hasTorch == true {
                Button { setTorch(!torchOn) } label: {
                    Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Brand.coral)
                        .frame(width: 44, height: 44)
                        .background(Brand.blush)
                        .clipShape(Circle())
                }
                .accessibilityLabel(torchOn ? "Выключить фонарик" : "Включить фонарик")
                .padding()
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                Text(detected == nil ? "Покажите QR и номер автобуса под ним" : "QR считан. Ищу номер под ним")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                if let detected {
                    Button("Ввести номер вручную") { finish(detected) }
                        .font(.subheadline.bold())
                }
            }
            .foregroundColor(Brand.ink)
            .padding(12)
            .background(Brand.paper)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(16)
        }
        .onDisappear {
            if torchOn { setTorch(false) }
        }
    }

    private func finish(_ reading: ScanReading) {
        guard !finished else { return }
        finished = true
        onScan(reading)
    }

    private func setTorch(_ enabled: Bool) {
        guard let camera, camera.hasTorch, camera.isTorchAvailable || !enabled else { return }
        let mode: AVCaptureDevice.TorchMode = enabled ? .on : .off
        guard camera.isTorchModeSupported(mode) else { return }
        do {
            try camera.lockForConfiguration()
            defer { camera.unlockForConfiguration() }
            camera.torchMode = mode
            torchOn = enabled
        } catch {
            torchOn = camera.isTorchActive
        }
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    var onDetected: (ScanReading) -> Void
    var onScan: (ScanReading) -> Void
    var onError: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr]), .text(languages: ["en-US"])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        let coordinator = context.coordinator
        scanner.delegate = coordinator
        DispatchQueue.main.async { [weak scanner, weak coordinator] in
            guard let scanner, let coordinator, !coordinator.didFinish else { return }
            do {
                try scanner.startScanning()
            } catch {
                coordinator.fail()
            }
        }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.view = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(view: self) }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.delegate = nil
        coordinator.stop(scanner)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var view: QRScannerView
        var didFinish = false
        private var consensus = ScanNumberConsensus()
        private var previousReading: ScanReading?
        private var nextZoomTime: TimeInterval = 0
        private var nextPhotoTime: TimeInterval = 0
        private var targetSince: TimeInterval = 0
        private var targetLastSeen: TimeInterval = 0
        private var targetPayload: String?
        private var recoveredNumber: String?
        private var recoveredAt: TimeInterval = 0
        private var recoveryAttempts = 0
        private var recoveryTask: Task<Void, Never>?

        init(view: QRScannerView) { self.view = view }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            analyze(allItems, scanner: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            analyze(allItems, scanner: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            analyze(allItems, scanner: scanner)
        }

        func dataScanner(_ scanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            fail()
        }

        func fail() {
            guard !didFinish else { return }
            didFinish = true
            recoveryTask?.cancel()
            view.onError("Не удалось запустить сканер. Проверьте доступ к камере в настройках.")
        }

        func stop(_ scanner: DataScannerViewController) {
            didFinish = true
            recoveryTask?.cancel()
            scanner.stopScanning()
        }

        private func finish(_ scanner: DataScannerViewController, payload: String, number: String, candidates: [String]) {
            guard !didFinish else { return }
            stop(scanner)
            view.onScan(ScanReading(payload: payload, number: number, candidates: candidates))
        }

        private func analyze(_ items: [RecognizedItem], scanner: DataScannerViewController) {
            guard !didFinish else { return }
            var codes: [(payload: String, bounds: CGRect)] = []
            var labels: [(number: String, bounds: CGRect)] = []
            for item in items {
                switch item {
                case .barcode(let code):
                    if let payload = code.payloadStringValue,
                       !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let bounds = boundingRect(code.bounds)
                        if bounds.width > 0, bounds.height > 0 { codes.append((payload, bounds)) }
                    }
                case .text(let text):
                    if let number = findBusNumber(in: text.transcript) {
                        labels.append((number, boundingRect(text.bounds)))
                    }
                @unknown default:
                    break
                }
            }

            let ordered = codes.sorted { $0.bounds.area > $1.bounds.area }
            guard let largest = ordered.first else { return }
            let paired = ordered.lazy.map { code in
                (code, numbersBelow(code.bounds, labels: labels))
            }.first { !$0.1.isEmpty }
            let code = paired?.0 ?? largest
            let candidates = paired?.1 ?? []
            let qrNumber = findBusNumber(in: code.payload.removingPercentEncoding ?? code.payload)
            let detected = ScanReading(payload: code.payload, number: nil, candidates: candidates)
            if previousReading?.payload != detected.payload || previousReading?.candidates != candidates {
                previousReading = detected
                view.onDetected(detected)
            }

            let now = ProcessInfo.processInfo.systemUptime
            if targetPayload != code.payload || now - targetLastSeen > 3 {
                targetPayload = code.payload
                targetSince = now
                recoveryAttempts = 0
                recoveredNumber = nil
            }
            targetLastSeen = now

            if let number = candidates.first ?? qrNumber {
                if candidates.isEmpty || consensus.isStable(payload: code.payload, number: number, now: now)
                    || (number == recoveredNumber && now - recoveredAt < 6) {
                    finish(scanner, payload: code.payload, number: number, candidates: candidates)
                }
                return
            }

            if now >= nextZoomTime, zoomForSmallQR(code.bounds, scanner: scanner) {
                nextZoomTime = now + 0.8
                nextPhotoTime = max(nextPhotoTime, now + 0.55)
            }
            if recoveryTask == nil, recoveryAttempts < 4, now >= nextPhotoTime, now - targetSince >= 1.0 {
                tryStillFrame(scanner, payload: code.payload, now: now)
            }
        }

        private func tryStillFrame(_ scanner: DataScannerViewController, payload: String, now: TimeInterval) {
            recoveryAttempts += 1
            nextPhotoTime = now + 2
            recoveryTask = Task { [weak self, weak scanner] in
                guard let self else { return }
                defer { self.recoveryTask = nil }
                guard let scanner, !Task.isCancelled,
                      let photo = try? await scanner.capturePhoto(), let image = photo.cgImage else { return }
                let orientation = photo.imageOrientation.visionOrientation
                let reading = await Task.detached(priority: .userInitiated) {
                    ScanPhotoRecovery.busNumber(in: image, orientation: orientation, matching: payload)
                }.value
                let completedAt = ProcessInfo.processInfo.systemUptime
                guard !Task.isCancelled, !self.didFinish, self.targetPayload == payload,
                      completedAt - self.targetLastSeen < 3, let number = reading else { return }
                if self.recoveredNumber == number && completedAt - self.recoveredAt < 6 {
                    self.finish(scanner, payload: payload, number: number, candidates: [number])
                } else {
                    self.recoveredNumber = number
                    self.recoveredAt = completedAt
                }
            }
        }

        private func zoomForSmallQR(_ qr: CGRect, scanner: DataScannerViewController) -> Bool {
            let viewfinder = scanner.view.bounds
            let qrSize = max(qr.width, qr.height)
            guard viewfinder.width > 0, viewfinder.height > 0, qrSize > 0 else { return false }

            // Keep the area where the number should appear below the QR in frame.
            let horizontalExtent = abs(qr.midX - viewfinder.midX) + qrSize * 0.8
            let verticalExtent = max(abs(qr.minY - viewfinder.midY), abs(qr.maxY + qrSize - viewfinder.midY))
            let zoomLimit = min(scanner.maxZoomFactor, scanner.minZoomFactor * 3.2)
            let step = min(
                min(viewfinder.width, viewfinder.height) * 0.39 / qrSize,
                viewfinder.width * 0.48 / horizontalExtent,
                viewfinder.height * 0.48 / verticalExtent,
                zoomLimit / scanner.zoomFactor
            )
            guard step >= 1.15 else { return false }
            scanner.zoomFactor = min(zoomLimit, scanner.zoomFactor * step)
            return true
        }
    }
}

private func boundingRect(_ bounds: RecognizedItem.Bounds) -> CGRect {
    let corners = [bounds.topLeft, bounds.topRight, bounds.bottomRight, bounds.bottomLeft]
    let xs = corners.map(\.x)
    let ys = corners.map(\.y)
    let x = xs.min() ?? 0
    let y = ys.min() ?? 0
    return CGRect(x: x, y: y, width: (xs.max() ?? x) - x, height: (ys.max() ?? y) - y)
}

private func numbersBelow(_ qr: CGRect, labels: [(number: String, bounds: CGRect)]) -> [String] {
    let ranked: [(number: String, distance: CGFloat)] = labels.compactMap { label in
        let down = label.bounds.midY - qr.maxY
        let across = abs(label.bounds.midX - qr.midX)
        guard down > 0, down <= qr.height * 1.45, across <= qr.width * 0.90 else { return nil }
        return (label.number, down + across)
    }
    var seen = Set<String>()
    return ranked.sorted { $0.distance < $1.distance }.compactMap { candidate in
        seen.insert(candidate.number).inserted ? candidate.number : nil
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}

private extension UIImage.Orientation {
    var visionOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .upMirrored: return .upMirrored
        case .down: return .down
        case .downMirrored: return .downMirrored
        case .left: return .left
        case .leftMirrored: return .leftMirrored
        case .right: return .right
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
