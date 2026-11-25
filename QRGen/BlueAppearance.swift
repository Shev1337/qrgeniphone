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
            .onLongPressGesture(minimumDuration: 0.7, perform: onSwitch)
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
    let date: String
    let onClose: () -> Void
    let onPrint: () -> Void
    @State private var qrExpanded = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    header
                    details
                }
                .frame(maxWidth: 450)
                .clipShape(RoundedRectangle(cornerRadius: 23))
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(minHeight: proxy.size.height)
                .frame(maxWidth: .infinity)
            }
            .background {
                BlueAppearance.navy.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Чек QRArest")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.white.opacity(0.13), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Закрыть чек")
            }
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: qrExpanded ? 320 : 220)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .onTapGesture { qrExpanded.toggle() }
                .accessibilityAction(named: Text(qrExpanded ? "Уменьшить QR-код" : "Увеличить QR-код")) {
                    qrExpanded.toggle()
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("QR-код билета")
                .accessibilityIdentifier("ticket.qr")
        }
        .padding(16)
        .foregroundStyle(.white)
        .background(BlueAppearance.navy)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !ticket.caption.isEmpty {
                Text("Номер транспорта")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BlueAppearance.muted)
                Text(ticket.caption.uppercased())
                    .font(.title2.bold().monospacedDigit())
                    .textSelection(.enabled)
            }
            if !ticket.title.isEmpty {
                Text(ticket.title).font(.subheadline).foregroundStyle(BlueAppearance.muted)
            }
            Divider().overlay(BlueAppearance.line)
            LabeledContent("Создан", value: date)
                .font(.subheadline)
            LabeledContent("Сумма в чеке", value: "\(receiptAmountTenge) ₸")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 14) {
                Button(action: onPrint) { Label("Квитанция", systemImage: "receipt") }
                Spacer(minLength: 0)
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(ticket.caption.isEmpty ? "QR-код" : ticket.caption.uppercased(), image: Image(uiImage: image))
                ) {
                    Label("Поделиться", systemImage: "square.and.arrow.up")
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(BlueAppearance.accent)
            .padding(.top, 8)
        }
        .foregroundStyle(BlueAppearance.ink)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
    }
}
