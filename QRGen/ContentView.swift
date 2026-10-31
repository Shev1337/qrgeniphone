import SwiftUI
import CoreImage.CIFilterBuiltins

struct SavedItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var link: String
    var caption: String
    var title: String = ""

    enum CodingKeys: String, CodingKey { case id, link, caption, title }

    init(link: String, caption: String, title: String) {
        self.link = link
        self.caption = caption
        self.title = title
    }

    // Старые сохранения (без заголовка) продолжают читаться
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        link = (try? c.decode(String.self, forKey: .link)) ?? ""
        caption = (try? c.decode(String.self, forKey: .caption)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
    }
}

struct ContentView: View {
    @AppStorage("savedLink") private var link = ""
    @AppStorage("savedCaption") private var caption = ""
    @AppStorage("savedTitle") private var title = ""
    @AppStorage("savedItems") private var savedData = ""
    @AppStorage("density") private var density = 0

    @State private var showCard = false
    @State private var expanded = false
    @State private var drag: CGFloat = 0

    private let backdrop = Color(red: 0.85, green: 0.86, blue: 0.88)
    private let collapsedRatio: CGFloat = 0.82

    private var items: [SavedItem] {
        (try? JSONDecoder().decode([SavedItem].self, from: Data(savedData.utf8))) ?? []
    }

    private func setItems(_ new: [SavedItem]) {
        if let data = try? JSONEncoder().encode(new),
           let str = String(data: data, encoding: .utf8) {
            savedData = str
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()
                form

                if showCard {
                    backdrop
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture { close() }
                        .zIndex(1)

                    card(size: geo.size)
                        .transition(.move(edge: .bottom))
                        .zIndex(2)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Главный экран

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QR-генератор")
                .font(.largeTitle.bold())
                .foregroundColor(.black)
                .padding(.top, 24)

            TextField("Ссылка на сайт", text: $link)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            TextField("Текст сверху (необязательно)", text: $title)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            TextField("Подпись под QR-кодом", text: $caption)
                .textInputAutocapitalization(.characters)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                Text("Плотность QR-кода")
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.5))
                Picker("Плотность QR-кода", selection: $density) {
                    Text("Обычная").tag(0)
                    Text("Плотная").tag(1)
                    Text("Максимум").tag(2)
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 12) {
                Button {
                    openCard()
                } label: {
                    Text("Создать QR-код")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(link.isEmpty ? Color(white: 0.75) : Color.black)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(link.isEmpty)

                Button {
                    hideKeyboard()
                    saveCurrent()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 56, height: 52)
                        .background(Color(white: 0.95))
                        .foregroundColor(link.isEmpty ? Color(white: 0.7) : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(link.isEmpty)
            }

            if !items.isEmpty {
                Text("Сохранённые")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.top, 8)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(items) { item in
                            row(item)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }

    private func row(_ item: SavedItem) -> some View {
        let primary: String = !item.caption.isEmpty ? item.caption.uppercased()
            : (!item.title.isEmpty ? item.title : item.link)

        return HStack(spacing: 12) {
            Button {
                link = item.link
                caption = item.caption
                title = item.title
                openCard()
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(primary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    if primary != item.link {
                        Text(item.link)
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                setItems(items.filter { $0.id != item.id })
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.55))
                    .padding(8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func saveCurrent() {
        let new = SavedItem(link: link, caption: caption, title: title)
        var list = items
        list.removeAll { $0.link == new.link && $0.caption == new.caption && $0.title == new.title }
        list.insert(new, at: 0)
        setItems(list)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Карточка с QR

    private func card(size: CGSize) -> some View {
        let image = makeQR(from: densePayload(link, level: density))
        let full = size.height
        let collapsed = full * collapsedRatio
        let base = expanded ? full : collapsed
        let h = min(full, max(base - drag, full * 0.5))
        // 0 — обычный размер, 1 — на весь экран
        let t = min(1, max(0, (h - collapsed) / max(full - collapsed, 1)))
        
        let qrSide = lerp(230, min(size.width - 56, 390), t)

        return VStack(spacing: 0) {
            // Полоска сверху: тянуть вверх — развернуть, вниз — свернуть/закрыть
            Capsule()
                .fill(Color(white: 0.8))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { toggleExpanded() }

            HStack(alignment: .top) {
                if title.isEmpty {
                    Spacer()
                } else {
                    Text(title)
                        .font(.system(size: lerp(18, 26, t), weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(8)
                }
            }

            Spacer(minLength: 2)

            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: qrSide, height: qrSide)
                .padding(8)
                .background(Color.white)

            // СЕРЫЙ ТЕКСТ ПОД QR-КОДОМ
            Text("Здесь будет ваше описание QR-кода")
                .font(.system(size: lerp(11, 13, t), weight: .regular))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 4)
                .padding(.horizontal, 16)

            if !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.system(size: lerp(15, 20, t), weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.top, lerp(6, 10, t))
                    .padding(.horizontal, 16)
            }

            Spacer(minLength: 8)

            HStack(spacing: 44) {
                Button {
                    printQR(image: image, title: title, caption: caption)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "printer")
                            .font(.system(size: 18))
                        Text("Печать")
                            .font(.caption)
                    }
                    .foregroundColor(.black)
                }

                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(caption.isEmpty ? "QR-код" : caption.uppercased(), image: Image(uiImage: image))
                ) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18))
                        Text("Поделиться")
                            .font(.caption)
                    }
                    .foregroundColor(.black)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: h, alignment: .top)
        .background(
            TopRounded(radius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { drag = $0.translation.height }
            .onEnded { value in
                let dy = value.translation.height
                let predicted = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    if expanded {
                        if dy > 100 || predicted > 250 { expanded = false }
                        drag = 0
                    } else if dy < -50 || predicted < -200 {
                        expanded = true
                        drag = 0
                    } else if dy > 130 || predicted > 300 {
                        showCard = false
                    } else {
                        drag = 0
                    }
                }
            }
    }

    private func openCard() {
        hideKeyboard()
        expanded = false
        drag = 0
        withAnimation(.easeOut(duration: 0.3)) { showCard = true }
    }

    private func toggleExpanded() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            expanded.toggle()
            drag = 0
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.25)) { showCard = false }
    }
}

struct TopRounded: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        ).cgPath)
    }
}

func makeQR(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "H"
    guard let output = filter.outputImage else { return UIImage() }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return UIImage() }
    return UIImage(cgImage: cg)
}

@MainActor
func printQR(image: UIImage, title: String, caption: String) {
    let content = VStack(spacing: 24) {
        if !title.isEmpty {
            Text(title)
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
        }
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 700, height: 700)
        
        // Серый текст для печати
        Text("Покажите QR-код контроллеру")
            .font(.system(size: 32, weight: .regular))
            .foregroundColor(Color(white: 0.55))
            .multilineTextAlignment(.center)

        if !caption.isEmpty {
            Text(caption.uppercased())
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
        }
    }
    .padding(60)
    .background(Color.white)

    let renderer = ImageRenderer(content: content)
    renderer.scale = 2
    guard let sheet = renderer.uiImage else { return }

    let info = UIPrintInfo(dictionary: nil)
    info.outputType = .general
    info.jobName = caption.isEmpty ? "QR-код" : caption

    let controller = UIPrintInteractionController.shared
    controller.printInfo = info
    controller.printingItem = sheet
    controller.present(animated: true)
}

/// Делает QR плотнее: к http(s)-ссылке добавляется «хвост» после #,
/// который сайт игнорирует. Чем длиннее данные, тем больше клеток в коде.
func densePayload(_ link: String, level: Int) -> String {
    let lower = link.lowercased()
    guard level > 0,
          lower.hasPrefix("http://") || lower.hasPrefix("https://"),
          !link.contains("#") else { return link }

    let target = level == 1 ? 55 : 95
    let need = target - link.utf8.count - 1
    guard need > 0 else { return link }

    var seed = UInt64(5381)
    for b in link.utf8 { seed = seed &* 33 &+ UInt64(b) }
    let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    var tail = ""
    for _ in 0..<need {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        tail.append(alphabet[Int((seed >> 33) % UInt64(alphabet.count))])
    }
    return link + "#" + tail
}
