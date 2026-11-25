import SwiftUI

private enum BlueAppearance {
    static let accent = Color(hex: "1643BA")
    static let navy = Color(hex: "122863")
    static let canvas = Color(hex: "EEF3FC")
    static let ink = Color(hex: "15244D")
    static let muted = Color(hex: "4A5A78")
    static let line = Color(hex: "D7E1F5")
}

struct AppearanceMark: View {
    let imageName: String
    let onSwitch: () -> Void

    var body: some View {
        Image(imageName)
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle())
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.7, maximumDistance: 22)
                    .onEnded { _ in onSwitch() }
            )
            .accessibilityLabel("Значок QRArest")
            .accessibilityIdentifier("appearance.toggle")
            .accessibilityAction(named: Text("Сменить оформление"), onSwitch)
    }
}

struct BlueStartScreen: View {
    let onScan: () -> Void
    let onServices: () -> Void
    let onHistory: () -> Void
    let onSwitchAppearance: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 11) {
                    AppearanceMark(imageName: "AppBrandBlue", onSwitch: onSwitchAppearance)
                    Text("QRArest")
                        .font(.title3.bold())
                        .foregroundStyle(BlueAppearance.ink)
                    Spacer()
                }

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("QR и чеки")
                            .font(.title.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text("Сканирование транспорта")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 32, weight: .medium))
                        .frame(width: 58, height: 58)
                        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .padding(19)
                .background(
                    LinearGradient(colors: [BlueAppearance.navy, BlueAppearance.accent], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 24)
                )

                VStack(spacing: 0) {
                    shortcut("История чеков", icon: "clock", identifier: "history.open.home", action: onHistory)
                    Divider().overlay(BlueAppearance.line).padding(.leading, 58)
                    shortcut("Ручной ввод", icon: "pencil", identifier: "services.open.manual", action: onServices)
                }
                .background(.white, in: RoundedRectangle(cornerRadius: 18))
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { navigation }
        .background { BlueAppearance.canvas.ignoresSafeArea() }
    }

    private var navigation: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Label("Главная", systemImage: "house.fill")
                .labelStyle(BlueTabLabel())
                .foregroundStyle(BlueAppearance.accent)
                .accessibilityAddTraits(.isSelected)
                .frame(maxWidth: .infinity)

            Button(action: onScan) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 62, height: 62)
                    .background(BlueAppearance.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Сканировать QR-код")
            .accessibilityIdentifier("scan.open")
            .frame(maxWidth: .infinity)

            Button(action: onServices) {
                Label("Меню", systemImage: "line.3.horizontal")
                    .labelStyle(BlueTabLabel())
                    .foregroundStyle(BlueAppearance.muted)
                    .frame(minWidth: 54, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("services.open")
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background { Color.white.ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { Divider().overlay(BlueAppearance.line) }
    }

    private func shortcut(_ title: String, icon: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(BlueAppearance.accent)
                    .frame(width: 34, height: 34)
                    .background(BlueAppearance.canvas, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 6)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BlueAppearance.muted)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(BlueAppearance.ink)
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct BlueTabLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 5) {
            configuration.icon.font(.system(size: 20, weight: .semibold))
            configuration.title.font(.caption.weight(.semibold))
        }
        .padding(.bottom, 7)
    }
}

struct BlueReceiptView: View {
    let ticket: SavedItem
    let image: UIImage
    let onClose: () -> Void
    let onPrint: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var qrExpanded = false

    private let accentText = Color(hex: "B1F3EA")
    private let secondaryText = Color(hex: "DFE8FF")

    private var route: String {
        let title = ticket.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Не указан" }
        return title.allSatisfy(\.isNumber) ? "№ \(title)" : title
    }

    private var transport: String {
        let number = ticket.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return number.isEmpty ? "Не указан" : number.uppercased()
    }

    private var creation: (day: String, time: String)? {
        guard let date = ticket.date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        let day = formatter.string(from: date)
        formatter.dateFormat = "HH:mm"
        return (day, formatter.string(from: date))
    }

    var body: some View {
        GeometryReader { proxy in
            let qrWidth = max(0, min(proxy.size.width - 68, 380))
            ScrollView {
                VStack(spacing: 16) {
                    header
                    qrPanel(side: qrExpanded ? qrWidth : min(qrWidth * 0.9, 292))
                    routeLabel
                    perforation
                    details
                    actions
                }
                .padding(16)
                .frame(maxWidth: 450)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        colors: [BlueAppearance.accent, BlueAppearance.navy],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 26)
                )
                .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
            }
            .background {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityAction(.escape, onClose)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Чек QRArest")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Демо-билет")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentText)
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Закрыть чек")
        }
    }

    private func qrPanel(side: CGFloat) -> some View {
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: side * 0.8, height: side * 0.8)
            .frame(width: side, height: side)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .onTapGesture { qrExpanded.toggle() }
            .accessibilityAction(named: Text(qrExpanded ? "Уменьшить QR-код" : "Увеличить QR-код")) {
                qrExpanded.toggle()
            }
            .accessibilityLabel("QR-код билета")
            .accessibilityIdentifier("ticket.qr")
    }

    private var routeLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Маршрут")
                .font(.subheadline)
                .foregroundStyle(accentText)
            Text(route)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var perforation: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0.5))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0.5))
            }
            .stroke(.white.opacity(0.38), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .frame(height: 1)
        .accessibilityHidden(true)
    }

    private var detailLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
    }

    private var details: some View {
        VStack(spacing: 8) {
            if let creation {
                detailLayout {
                    detail("Дата создания", value: creation.day)
                    detail("Время", value: creation.time)
                }
            } else {
                detail("Дата создания", value: "Не сохранена")
            }
            detail("Сумма в чеке", value: "\(receiptAmountTenge) ₸")
            detail("Номер транспорта", value: transport)
        }
    }

    private func detail(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(secondaryText)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .textSelection(.enabled)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        detailLayout {
            Button(action: onPrint) {
                actionLabel("Квитанция", systemImage: "receipt")
            }
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(ticket.caption.isEmpty ? "QR-код" : transport, image: Image(uiImage: image))
            ) {
                actionLabel("Поделиться", systemImage: "square.and.arrow.up")
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
    }
}
