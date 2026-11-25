import SwiftUI

struct StartScreen: View {
    let onScan: () -> Void
    let onServices: () -> Void

    private let ink = Color(hex: "30252B")
    private let muted = Color(hex: "715C64")
    private let coral = Color(hex: "B83C4E")
    private let blush = Color(hex: "FBE9EA")
    private let line = Color(hex: "F0DBDE")
    private let paper = Color(hex: "FFF8F7")

    private let plannedSections = [
        ("Магазины", "cart"), ("Госуслуги", "building.columns"),
        ("Платежи", "creditcard"), ("Переводы", "arrow.left.arrow.right"),
        ("Поездки", "airplane"), ("Работа", "briefcase"),
        ("Банк", "banknote"), ("Акции", "tag")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                brand
                searchPreview
                banner
                plannedGrid
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { navigationBar }
        .background(.white.ignoresSafeArea())
    }

    private var brand: some View {
        HStack(spacing: 11) {
            Image(systemName: "ticket")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(coral)
                .frame(width: 42, height: 42)
                .background(blush, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("QRGen").font(.headline.bold()).foregroundStyle(ink)
                Text("Рабочее место контролёра").font(.caption).foregroundStyle(muted)
            }
        }
    }

    private var searchPreview: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(muted)
                .accessibilityHidden(true)
            Text("Поиск по разделам").font(.subheadline).foregroundStyle(muted)
            Spacer(minLength: 6)
            Text("Скоро").font(.caption.weight(.medium)).foregroundStyle(coral)
        }
        .padding(13)
        .background(paper, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var banner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("QR и чеки")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .accessibilityAddTraits(.isHeader)
                Text("Сканирование и история")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: "FFEBEA"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 31, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 19))
                .overlay {
                    RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(0.36))
                }
                .accessibilityHidden(true)
        }
        .padding(.vertical, 19)
        .padding(.horizontal, 17)
        .background(
            LinearGradient(
                colors: [Color(hex: "91344B"), Color(hex: "CD5861")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }

    private var plannedGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Будущие разделы")
                .font(.headline)
                .foregroundStyle(ink)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(plannedSections.indices, id: \.self) { index in
                    let (title, symbol) = plannedSections[index]
                    HStack(spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(coral)
                            .frame(width: 21)
                            .accessibilityHidden(true)
                        Text(title)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(ink)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(minHeight: 54)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(line) }
                }
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 0) {
            tabLabel("Главная", icon: "house", tint: coral)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isSelected)

            Button(action: onScan) {
                tabLabel("QR", icon: "qrcode.viewfinder", tint: coral, emphasized: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Сканировать QR-код")
            .accessibilityIdentifier("scan.open")

            Button(action: onServices) {
                tabLabel("Сервисы", icon: "square.grid.2x2", tint: ink)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("services.open")
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(.white)
        .overlay(alignment: .top) { Divider().overlay(line) }
    }

    private func tabLabel(_ title: String, icon: String, tint: Color, emphasized: Bool = false) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 21, weight: .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 4)
                .background(emphasized ? blush : .clear, in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)
            Text(title).font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .frame(maxWidth: .infinity, minHeight: 56)
        .contentShape(Rectangle())
    }
}
