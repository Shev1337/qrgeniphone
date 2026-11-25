import SwiftUI
import UIKit

struct DemoTicketView: View {
    let item: SavedItem
    let qrImage: UIImage
    let onClose: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let dateText: String
    private let timeText: String
    private let mint = Color(red: 0.65, green: 0.96, blue: 0.91)
    private let muted = Color(red: 0.80, green: 0.85, blue: 0.96)

    init(item: SavedItem, qrImage: UIImage, onClose: @escaping () -> Void) {
        self.item = item
        self.qrImage = qrImage
        self.onClose = onClose

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        dateText = formatter.string(from: item.date)
        formatter.dateFormat = "HH:mm"
        timeText = formatter.string(from: item.date)
    }

    private var route: String {
        let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Не указан" }
        return title.allSatisfy(\.isNumber) ? "№ \(title)" : title
    }

    private var transport: String {
        let caption = item.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return caption.isEmpty ? "Не указан" : caption.uppercased()
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            qrPanel

            VStack(alignment: .leading, spacing: 4) {
                Text("Маршрут")
                    .font(.subheadline)
                    .foregroundStyle(mint)
                Text(route)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            perforation

            details
            actions
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.26, blue: 0.56),
                            Color(red: 0.07, green: 0.13, blue: 0.29)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
        }
        .accessibilityAction(.escape, onClose)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("Демо-билет", systemImage: "ticket")
                .font(.headline)
                .foregroundStyle(mint)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.14), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть билет")
        }
    }

    private var qrPanel: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.white)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(geometry.size.width * 0.10)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .frame(maxWidth: 310)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("QR-код")
    }

    private var perforation: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0.5))
            }
            .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }

    private var details: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))

        return VStack(spacing: 8) {
            layout {
                detail("Дата создания", value: dateText)
                detail("Время", value: timeText)
            }
            detail("Номер транспорта", value: transport)
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(muted)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        return layout {
            Button(action: printTicket) {
                actionLabel("Печать", systemImage: "printer")
            }

            ShareLink(
                item: Image(uiImage: qrImage),
                preview: SharePreview("QR-код", image: Image(uiImage: qrImage))
            ) {
                actionLabel("Поделиться QR", systemImage: "square.and.arrow.up")
            }
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 8)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
    }

    @MainActor
    private func printTicket() {
        let content = VStack(spacing: 20) {
            Text("Демо-билет")
                .font(.system(size: 48, weight: .bold))
            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 500, height: 500)
            Text("Маршрут: \(route)")
                .font(.system(size: 36, weight: .semibold))
            Text("Номер транспорта: \(transport)")
            Text("Дата создания: \(dateText) · \(timeText)")
        }
        .font(.system(size: 24))
        .multilineTextAlignment(.center)
        .frame(width: 580)
        .padding(50)
        .foregroundStyle(.black)
        .background(.white)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let page = renderer.uiImage else { return }

        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "Демо-билет"
        let controller = UIPrintInteractionController.shared
        controller.printInfo = info
        controller.printingItem = page
        controller.present(animated: true)
    }
}
