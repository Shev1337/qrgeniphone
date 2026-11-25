import SwiftUI

struct ScanFlowSheet: View {
    let initialTitle: String
    let onConfirm: (SavedItem, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var review: ReceiptDraft?
    @State private var detent: PresentationDetent = .large
    @State private var cameraError: String?
    @State private var showCameraError = false

    #if DEBUG
    @State private var testScanCount = 0
    #endif

    static var usesTestScanner: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--ui-test-scanner")
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if let review {
                ReceiptConfirmationView(
                    draft: review,
                    onCancel: { dismiss() },
                    onRescan: {
                        detent = .large
                        self.review = nil
                    },
                    onConfirm: { ticket, image in
                        onConfirm(ticket, image)
                        dismiss()
                    }
                )
            } else {
                scanner
            }
        }
        .presentationDetents(review == nil ? [.large] : [ReceiptConfirmationView.compactDetent, .large], selection: $detent)
        .presentationDragIndicator(review == nil ? .automatic : .visible)
        .alert("QRArest", isPresented: $showCameraError) {
            Button("ОК", role: .cancel) { dismiss() }
        } message: {
            Text(cameraError ?? "")
        }
    }

    @ViewBuilder
    private var scanner: some View {
        #if DEBUG
        if Self.usesTestScanner {
            Button("Считать тестовый QR") {
                testScanCount += 1
                receive(ScanReading(
                    payload: "https://example.com/scan/\(testScanCount)?ticket=123",
                    number: testScanCount == 1 ? "721BG04" : "837AY04"
                ))
            }
            .accessibilityIdentifier("scan.fixture.read")
        } else {
            liveScanner
        }
        #else
        liveScanner
        #endif
    }

    private var liveScanner: some View {
        ScannerSheet(onScan: receive, onError: { message in
            cameraError = message
            showCameraError = true
        })
    }

    private func receive(_ reading: ScanReading) {
        guard review == nil, !reading.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let ticket = SavedItem(
            link: reading.payload,
            caption: reading.number ?? "",
            title: initialTitle,
            fromScan: true
        )
        review = ReceiptDraft(ticket: ticket, candidates: reading.candidates)
        detent = ReceiptConfirmationView.compactDetent
    }
}
