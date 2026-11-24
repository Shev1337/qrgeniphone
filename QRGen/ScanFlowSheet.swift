import SwiftUI

struct ScanFlowSheet: View {
    let initialTitle: String
    let onConfirm: (SavedItem, UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var review: ScanReview?
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
                ScanConfirmationView(
                    review: review,
                    initialTitle: initialTitle,
                    onCancel: { dismiss() },
                    onRescan: { self.review = nil },
                    onConfirm: { ticket, image in
                        onConfirm(ticket, image)
                        dismiss()
                    }
                )
            } else {
                scanner
            }
        }
        .alert("QR-генератор", isPresented: $showCameraError) {
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
        guard review == nil, let result = ScanReview(reading: reading) else { return }
        review = result
    }
}

private struct ScanReview {
    let reading: ScanReading
    let image: UIImage?

    init?(reading: ScanReading) {
        guard !reading.payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.reading = reading
        let generated = makeQR(from: reading.payload)
        image = generated.cgImage == nil ? nil : generated
    }
}

private struct ScanConfirmationView: View {
    let review: ScanReview
    let onCancel: () -> Void
    let onRescan: () -> Void
    let onConfirm: (SavedItem, UIImage) -> Void

    @State private var confirmedCaption: String
    @State private var confirmedTitle: String

    init(
        review: ScanReview,
        initialTitle: String,
        onCancel: @escaping () -> Void,
        onRescan: @escaping () -> Void,
        onConfirm: @escaping (SavedItem, UIImage) -> Void
    ) {
        self.review = review
        self.onCancel = onCancel
        self.onRescan = onRescan
        self.onConfirm = onConfirm
        _confirmedCaption = State(initialValue: review.reading.number ?? "")
        _confirmedTitle = State(initialValue: initialTitle)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Создать чек?")
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Данные QR-кода:")
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                        Text(review.reading.payload)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .textSelection(.enabled)
                            .accessibilityIdentifier("scan.review.payload")
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let image = review.image {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 104, height: 104)
                            .accessibilityLabel("QR-код на чеке")
                            .accessibilityIdentifier("scan.review.preview")
                    } else {
                        Text("Не удалось создать QR-код из считанных данных.")
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    // Если камера поймала несколько текстов — показываем их для выбора
                    if !review.reading.candidates.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Выберите нужную надпись с экрана:")
                                .font(.footnote)
                                .foregroundColor(Color(white: 0.5))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(review.reading.candidates, id: \.self) { candidate in
                                        Button {
                                            confirmedCaption = candidate.uppercased()
                                        } label: {
                                            Text(candidate)
                                                .font(.system(size: 14, weight: .medium))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(confirmedCaption == candidate.uppercased() ? Color.black : Color(white: 0.92))
                                                .foregroundColor(confirmedCaption == candidate.uppercased() ? .white : .black)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Номер автобуса:")
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                        TextField("837AY04", text: $confirmedCaption)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("scan.review.number")
                        if !confirmedCaption.isEmpty && normalizeBusNumber(confirmedCaption) == nil {
                            Text("Проверьте формат номера, например 837AY04.")
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Текст сверху (необязательно):")
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                        TextField("Текст сверху", text: $confirmedTitle)
                            .padding()
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button("Пересканировать", action: onRescan)
                        .foregroundColor(.black)
                        .accessibilityIdentifier("scan.review.rescan")
                }
                .padding(20)
            }
            .navigationTitle("Подтверждение вывода")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать чек", action: confirmScan)
                        .bold()
                        .disabled(normalizeBusNumber(confirmedCaption) == nil || review.image == nil)
                        .accessibilityIdentifier("scan.review.confirm")
                }
            }
        }
    }

    private func confirmScan() {
        guard let number = normalizeBusNumber(confirmedCaption), let image = review.image else { return }
        let payload = review.reading.payload
        let ticket = SavedItem(
            link: payload,
            caption: number,
            title: confirmedTitle,
            qrPayload: payload,
            fromScan: true
        )
        onConfirm(ticket, image)
    }
}
