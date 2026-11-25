import SwiftUI

struct StartScreen: View {
    let onScan: () -> Void
    let onServices: () -> Void

    private let ink = Color(hex: "123B35")
    private let muted = Color(hex: "466B63")
    private let mint = Color(hex: "DBF1E9")
    private let page = Color(hex: "F3F8F5")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "ticket")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(mint, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    Text("QRGen")
                        .font(.headline)
                }
                .foregroundStyle(ink)

                Text("QR и чеки")
                    .font(.largeTitle.bold())
                    .foregroundStyle(ink)
                    .padding(.top, 6)
                    .accessibilityAddTraits(.isHeader)

                Button(action: onScan) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("QR")
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                            Text("Сканировать код")
                                .font(.subheadline)
                                .foregroundStyle(mint)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 58, height: 58)
                            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 25)
                    .background(
                        LinearGradient(colors: [ink, Color(hex: "087260")], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 26)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Сканировать QR-код")
                .accessibilityIdentifier("scan.open")

                Button(action: onServices) {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(ink)
                            .frame(width: 46, height: 46)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Сервисы")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(ink)
                            Text("Генератор и история чеков")
                                .font(.footnote)
                                .foregroundStyle(muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.forward")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ink)
                            .accessibilityHidden(true)
                    }
                    .padding(19)
                    .background(mint, in: RoundedRectangle(cornerRadius: 26))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("services.open")
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .background(page.ignoresSafeArea())
    }
}
