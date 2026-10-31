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

    // Форматирование текущей даты и времени
    private var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy HH:mm"
        return formatter.string(from: Date())
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()
                form

                if showCard {
                    // ФОНОВЫЙ ЭКРАН С НАДПИСЬЮ СВЕРХУ И ЗЕЛЕНОЙ ГАЛОЧКОЙ
                    ZStack(alignment: .top) {
                        backdrop
                            .ignoresSafeArea()
                            .onTapGesture { close() }

                        VStack(spacing: 8) {
                            // Текст в самом верху фона с меньшим отступом
                            Text("Ваш текст сверху на фоне")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.top, 12) // Уменьшенный отступ от верха экрана

                            // Зелёная иконка с белой галочкой и надпись «Успешно»
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white, .green) // Белая галочка на зелёном фоне
                                Text("Успешно")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                    // САМО ВЫПАДАЮЩЕЕ ОКНО (опущено ниже, чтобы не закрывать «Успешно»)
                    card(size: geo.size)
                        .padding(.top, 130) // <--- Окно опущено ниже
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

                if density > 0 && !link.isEmpty {
                    Text("В коде: \(densePayload(link, level: density))")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
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
        let uniquePayload = link.contains("?") ? "\(link)&rnd=\(Int(Date().timeIntervalSince1970 * 1000))" : "\(link)?rnd=\(Int(Date().timeIntervalSince1970 * 1000))"
        let image = makeQR(from: densePayload(uniquePayload, level: density))
        let full = size.height
        let collapsed = full * collapsedRatio
        let base = expanded ? full : collapsed
        let h = min(full, max(base - drag, full * 0.5))
        let t = min(1, max(0, (h - collapsed) / max(full - collapsed, 1)))
        
        let qrSide = lerp(240, min(size.width - 56, 330), t)
        let currentDateString = formattedCurrentDate

        return VStack(spacing: 0) {
            // Полоска сверху на карточке
            Capsule()
                .fill(Color(white: 0.8))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 2)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { toggleExpanded() }

            HStack(alignment: .center) {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: lerp(20, 26, t), weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                }
                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(8)
                }
            }
            .padding(.horizontal, 4)

            Spacer(minLength: 1)

            // QR-код
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: qrSide, height: qrSide)
                .padding(4)
                .background(Color.white)

            // 1. Первое описание (серое) сразу под QR-кодом
            Text("Покажите QR-код")
                .font(.system(size: lerp(12, 14, t), weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 32)
                .padding(.horizontal, 16)

            // 2. Основной текст (caption) с отступом
            if !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.system(size: lerp(16, 22, t), weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
            }

            // 3 и 4. Дата и второе описание объединены без отступа между ними
            VStack(spacing: 2) {
                Text(currentDateString)
                    .font(.system(size: lerp(12, 14, t), weight: .regular))
                    .foregroundColor(.black)

                Text("Сумма 100 ₸")
                    .font(.system(size: lerp(12, 14, t), weight: .light))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)

            Spacer(minLength: 8)

            HStack(spacing: 140) {
                Button {
                    printQR(image: image, title: title, caption: caption, dateString: currentDateString)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "receipt")
                            .font(.system(size: 18))
                        Text("Квитанция")
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
func printQR(image: UIImage, title: String, caption: String, dateString: String) {
    let content = VStack(spacing: 14) {
        if !title.isEmpty {
            Text(title)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        
        // Зелёная галочка с белой галкой при печати
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white, .green)
            Text("Успешно")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 580, height: 580)
        
        // 1. Первое описание для печати
        Text("Покажите QR-код")
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(Color(white: 0.45))
            .multilineTextAlignment(.center)

        // 2. Основной текст (caption) для печати
        if !caption.isEmpty {
            Text(caption.uppercased())
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
        }

        // 3 и 4. Дата и второе описание без отступа между ними для печати
        VStack(spacing: 4) {
            Text(dateString)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.black)

            Text("Сумма 100 ₸")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
        }
    }
    .padding(50)
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

/// Делает QR плотнее: добавляет к данным «хвост», чтобы клеток стало больше.
func densePayload(_ input: String, level: Int) -> String {
    let link = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard level > 0, !link.isEmpty else { return link }

    let target = level == 1 ? 55 : 95
    let lower = link.lowercased()
    let hasScheme = lower.hasPrefix("http://") || lower.hasPrefix("https://")
    let looksLikeDomain = !hasScheme && !link.contains(" ") && !link.contains(":") && link.contains(".")

    func filler(_ count: Int) -> String {
        var seed = UInt64(5381)
        for b in link.utf8 { seed = seed &* 33 &+ UInt64(b) }
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var tail = ""
        for _ in 0..<count {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            tail.append(alphabet[Int((seed >> 33) % UInt64(alphabet.count))])
        }
        return tail
    }

    if hasScheme || looksLikeDomain {
        let url = hasScheme ? link : "https://" + link
        if url.contains("#") { return url }
        let need = target - url.utf8.count - 1
        return need > 0 ? url + "#" + filler(need) : url
    }

    if !link.contains(":") {
        let need = target - link.utf8.count
        return need > 0 ? link + String(repeating: " ", count: need) : link
    }

    return link
}
