import SwiftUI

struct ReceiptDraft: Identifiable {
    let ticket: SavedItem
    let image: UIImage?
    let candidates: [String]
    let opensReceipt: Bool

    var id: UUID { ticket.id }

    init(ticket: SavedItem, candidates: [String] = [], opensReceipt: Bool = true) {
        self.ticket = ticket
        self.candidates = candidates
        self.opensReceipt = opensReceipt
        let qr = makeQR(from: ticket.payload)
        image = qr.cgImage == nil ? nil : qr
    }
}

struct ReceiptConfirmationView: View {
    static let compactDetent = PresentationDetent.fraction(0.78)

    let draft: ReceiptDraft
    let onCancel: () -> Void
    let onRescan: (() -> Void)?
    let onConfirm: (SavedItem, UIImage) -> Void

    @State private var number: String
    @State private var title: String
    @State private var didConfirm = false

    init(
        draft: ReceiptDraft,
        onCancel: @escaping () -> Void,
        onRescan: (() -> Void)? = nil,
        onConfirm: @escaping (SavedItem, UIImage) -> Void
    ) {
        self.draft = draft
        self.onCancel = onCancel
        self.onRescan = onRescan
        self.onConfirm = onConfirm
        _number = State(initialValue: draft.ticket.caption)
        _title = State(initialValue: draft.ticket.title)
    }

    private var normalizedNumber: String? { normalizeBusNumber(number) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Подтверждение чека")
                    .font(.system(.title2, design: .serif, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Отменить создание чека")
                .accessibilityIdentifier("receipt.review.cancel")
            }
            .padding(.horizontal, 20)
            .padding(.top, 13)
            .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 12) {
                    details
                    qrDetails
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .foregroundStyle(Brand.ink)
        .background { Brand.paper.ignoresSafeArea() }
        .tint(Brand.burgundy)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Сумма в чеке") {
                Text("\(receiptAmountTenge) ₸")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Brand.ink)
            }
            Divider().overlay(Brand.line)
            Text("Номер автобуса")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Brand.muted)
            TextField("837AY04", text: $number)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.headline.monospacedDigit())
                .padding(11)
                .background(Brand.paper, in: RoundedRectangle(cornerRadius: 11))
                .accessibilityLabel("Номер автобуса")
                .accessibilityIdentifier("receipt.review.number")
            if draft.ticket.fromScan && normalizedNumber == nil {
                Text("Введите номер в формате 837AY04.")
                    .font(.footnote)
                    .foregroundStyle(Brand.error)
            }
            if !draft.candidates.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(draft.candidates, id: \.self) { candidate in
                            let selected = normalizedNumber == candidate.uppercased()
                            Button {
                                number = candidate.uppercased()
                            } label: {
                                Text(candidate)
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 44)
                                    .foregroundStyle(selected ? Color.white : Brand.burgundy)
                                    .background(selected ? Brand.burgundy : Brand.blush, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
            }
            TextField("Текст на чеке (необязательно)", text: $title)
                .padding(11)
                .background(Brand.paper, in: RoundedRectangle(cornerRadius: 11))
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 17))
    }

    private var qrDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Данные QR-кода")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Brand.muted)
            Text(draft.ticket.payload)
                .font(.footnote)
                .textSelection(.enabled)
                .accessibilityIdentifier("receipt.review.payload")
            if let image = draft.image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .padding(6)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("QR-код на чеке")
                    .accessibilityIdentifier("receipt.review.preview")
            } else {
                Text("Эти данные не помещаются в QR-код чека.")
                    .font(.footnote)
                    .foregroundStyle(Brand.error)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 17))
    }

    private var actions: some View {
        VStack(spacing: 2) {
            if let onRescan {
                Button("Пересканировать", action: onRescan)
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("receipt.review.rescan")
            }
            let allowed = !didConfirm && draft.image != nil && (!draft.ticket.fromScan || normalizedNumber != nil)
            Button(action: confirm) {
                Text(draft.opensReceipt ? "Создать чек" : "Сохранить в историю")
                    .font(.headline)
                    .foregroundStyle(allowed ? Color.white : Brand.muted)
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(allowed ? Brand.burgundy : Brand.blush, in: RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(!allowed)
            .accessibilityIdentifier("receipt.review.confirm")
        }
        .frame(maxWidth: 500)
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Brand.paper)
        .overlay(alignment: .top) { Divider().overlay(Brand.line) }
    }

    private func confirm() {
        guard !didConfirm, let image = draft.image else { return }
        let formatted = normalizedNumber
        guard !draft.ticket.fromScan || formatted != nil else { return }

        didConfirm = true
        var ticket = draft.ticket
        ticket.caption = formatted ?? number.uppercased()
        ticket.title = title
        ticket.date = Date()
        onConfirm(ticket, image)
    }
}
