import SwiftUI
import CoreImage.CIFilterBuiltins
import VisionKit

// MARK: - Надежное расширение для работы с HEX-цветами в SwiftUI
extension Color {
    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Главное представление
struct ContentView: View {
    @AppStorage("savedLink") private var link = "https://avtobys.kz"
    @AppStorage("savedTitle") private var title = ""
    @AppStorage("savedItems") private var savedData = ""
    @AppStorage("density") private var density = 0

    @State private var caption = "04"
    @State private var sourceLink: String?
    @State private var showCard = false
    @State private var showScanner = false
    @State private var expanded = false
    @State private var drag: CGFloat = 0
    @State private var originalBrightness: CGFloat = 1.0

    @State private var errorMessage = ""
    @State private var showError = false
    @State private var currentTicket: SavedItem?
    @State private var currentQR: UIImage?

    // История уже сгенерированных QR
    @State private var showHistory = false

    // Состояния для меню действий и редактирования сохранённых
    @State private var selectedItemForAction: SavedItem? = nil
    @State private var showActionSheet = false
    @State private var showEditModal = false
    @State private var editingItem: SavedItem? = nil
    @State private var editCaption = ""
    @State private var editTitle = ""

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

    private func updateItem(_ updatedItem: SavedItem) {
        var list = items
        if let index = list.firstIndex(where: { $0.id == updatedItem.id }) {
            list[index] = updatedItem
            setItems(list)
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy HH:mm"
        return formatter.string(from: date)
    }

    private var canGenerate: Bool {
        !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (sourceLink != link || normalizeBusNumber(caption) != nil)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()
                form

                if showCard, let ticket = currentTicket, let image = currentQR {
                    ZStack(alignment: .top) {
                        backdrop
                            .ignoresSafeArea()
                            .onTapGesture { close() }

                        VStack(spacing: 8) {
                            Text("Билет Avtobys. Оплата проезда")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.top, 6)

                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.white, Color(hex: "169402"))
                                Text("Ваш платеж принят")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.top, 6)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)

                    card(size: geo.size, ticket: ticket, image: image)
                        .padding(.top, 130)
                        .transition(.move(edge: .bottom))
                        .zIndex(2)
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showScanner) {
            ScanFlowSheet(initialTitle: title) { ticket, image in
                openCard(ticket, image: image)
            }
        }
        .alert("QR-генератор", isPresented: $showError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog("Выберите действие", isPresented: $showActionSheet, presenting: selectedItemForAction) { item in
            Button("Вывести") {
                touchItem(item)
            }
            Button("Изменить") {
                editingItem = item
                editCaption = item.caption
                editTitle = item.title
                showEditModal = true
            }
            Button("Отмена", role: .cancel) {}
        } message: { item in
            let textToShow = !item.caption.isEmpty ? item.caption.uppercased() : (!item.title.isEmpty ? item.title : item.link)
            Text("Элемент: «\(textToShow)»")
        }
        .sheet(isPresented: $showEditModal) {
            NavigationView {
                VStack(spacing: 16) {
                    TextField("Подпись под QR-кодом", text: $editCaption)
                        .textInputAutocapitalization(.characters)
                        .padding()
                        .background(Color(white: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    TextField("Текст сверху (необязательно)", text: $editTitle)
                        .padding()
                        .background(Color(white: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Spacer()
                }
                .padding(20)
                .navigationTitle("Редактировать")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            showEditModal = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") {
                            if var item = editingItem {
                                item.caption = editCaption
                                item.title = editTitle
                                updateItem(item)
                            }
                            showEditModal = false
                        }
                    }
                }
            }
        }
        // Экран истории уже сгенерированных QR-кодов
        .sheet(isPresented: $showHistory) {
            NavigationView {
                VStack(spacing: 0) {
                    if items.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "clock")
                                .font(.system(size: 56))
                                .foregroundColor(Color(white: 0.55))
                            Text("История пуста")
                                .font(.headline)
                                .foregroundColor(.black)
                            Text("Сгенерированные QR-коды будут появляться здесь")
                                .font(.footnote)
                                .foregroundColor(Color(white: 0.55))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(items) { item in
                                historyRow(item)
                            }
                            .onDelete(perform: deleteHistoryItems)
                        }
                        .listStyle(.plain)
                    }
                }
                .navigationTitle("История QR-кодов")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") {
                            showHistory = false
                        }
                    }
                    if !items.isEmpty {
                        ToolbarItem(placement: .destructiveAction) {
                            Button("Очистить всё", role: .destructive) {
                                setItems([])
                                showHistory = false
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: showCard) { isOpen in
            if isOpen {
                originalBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
            } else {
                UIScreen.main.brightness = originalBrightness
            }
        }
    }

    // MARK: - Перемещение используемого билета наверх

    private func touchItem(_ item: SavedItem) {
        var ticket = item
        if ticket.qrPayload == nil {
            ticket.qrPayload = ticket.fromScan
                ? ticket.link
                : densePayload(makeTicketPayload(ticket.link, id: ticket.id), level: density)
        }
        openCard(ticket)
    }

    // MARK: - Обработка сканирования с выбором текстов

    private func beginScan() {
        hideKeyboard()
        if ScanFlowSheet.usesTestScanner {
            showScanner = true
            return
        }
        guard DataScannerViewController.isSupported else {
            presentError("Этот iPhone не поддерживает сканер VisionKit.")
            return
        }
        guard DataScannerViewController.isAvailable else {
            presentError("Для сканирования разрешите доступ к камере в настройках.")
            return
        }
        showScanner = true
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showError = true
    }

    // MARK: - Главный экран

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QR-генератор")
                .font(.largeTitle.bold())
                .foregroundColor(.black)
                .padding(.top, 24)

            HStack(spacing: 8) {
                TextField("Ссылка на сайт", text: Binding(
                    get: { link },
                    set: { value in
                        if value != link { sourceLink = nil }
                        link = value
                    }
                ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Button(action: beginScan) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 52, height: 52)
                        .background(Color(white: 0.95))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Сканировать QR-код")
                .accessibilityIdentifier("scan.open")
            }

            TextField("Текст сверху (необязательно)", text: $title)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            BusNumberField(text: $caption)
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
                    Text("В коде: \(sourceLink == link ? link : densePayload(link, level: density))")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 12) {
                Button {
                    saveCurrent(open: true)
                } label: {
                    Text("Создать QR-код")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canGenerate ? Color.black : Color(white: 0.75))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canGenerate)

                Button {
                    hideKeyboard()
                    saveCurrent()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 56, height: 52)
                        .background(Color(white: 0.95))
                        .foregroundColor(canGenerate ? .black : Color(white: 0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canGenerate)

                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 56, height: 52)
                        .background(Color(white: 0.95))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
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
                selectedItemForAction = item
                showActionSheet = true
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

    private func saveCurrent(open: Bool = false) {
        guard canGenerate else { return }
        let fromScan = sourceLink == link
        let input = fromScan ? link : link.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = normalizeBusNumber(caption) ?? caption.uppercased()
        var ticket = SavedItem(link: input, caption: number, title: title, fromScan: fromScan)
        ticket.qrPayload = fromScan ? input : densePayload(makeTicketPayload(input, id: ticket.id), level: density)
        if open {
            openCard(ticket)
        } else {
            setItems(ticket.addedToHistory(items))
        }
    }

    // MARK: - История

    private func historyRow(_ item: SavedItem) -> some View {
        let primary: String = !item.caption.isEmpty ? item.caption.uppercased()
            : (!item.title.isEmpty ? item.title : item.link)
        let dateString: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ru_RU")
            f.dateFormat = "d MMMM yyyy, HH:mm"
            return f.string(from: item.date)
        }()

        return Button {
            touchItem(item)
            showHistory = false
        } label: {
            HStack(spacing: 12) {
                Image(uiImage: makeQR(from: item.payload))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(primary)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                    Text(item.link)
                        .font(.footnote)
                        .foregroundColor(Color(white: 0.5))
                        .lineLimit(1)
                    Text(dateString)
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(white: 0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .buttonStyle(PlainButtonStyle())
        }
    }

    private func deleteHistoryItems(offsets: IndexSet) {
        var list = items
        list.remove(atOffsets: offsets)
        setItems(list)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Карточка с QR

    private func card(size: CGSize, ticket: SavedItem, image: UIImage) -> some View {
        let title = ticket.title
        let caption = ticket.caption
        let full = size.height
        let collapsed = full * collapsedRatio
        let base = expanded ? full : collapsed
        let h = min(full, max(base - drag, full * 0.5))
        let t = min(1, max(0, (h - collapsed) / max(full - collapsed, 1)))
        
        let qrSide = lerp(240, min(size.width - 56, 330), t)
        let currentDateString = formattedDate(ticket.date)

        return VStack(spacing: 0) {
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

            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: qrSide, height: qrSide)
                .padding(4)
                .background(Color.white)
                .accessibilityLabel("QR-код билета")
                .accessibilityIdentifier("ticket.qr")

            Text("Покажите QR-код контроллеру")
                .font(.system(size: lerp(12, 14, t), weight: .regular))
                .foregroundColor(Color(white: 0.45))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 32)
                .padding(.horizontal, 16)

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

            VStack(spacing: 2) {
                Text(currentDateString)
                    .font(.system(size: lerp(12, 14, t), weight: .regular))
                    .foregroundColor(.black)

                Text("Сумма 80 ₸")
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
                        close()
                    } else {
                        drag = 0
                    }
                }
            }
    }

    private func openCard(_ ticket: SavedItem, image: UIImage? = nil) {
        let qr = image ?? makeQR(from: ticket.payload)
        guard qr.cgImage != nil else {
            presentError("Эти данные не помещаются в QR-код чека.")
            return
        }
        hideKeyboard()
        setItems(ticket.addedToHistory(items))
        link = ticket.link
        caption = ticket.caption
        title = ticket.title
        sourceLink = ticket.fromScan ? ticket.link : nil
        currentTicket = ticket
        currentQR = qr
        expanded = false
        drag = 0
        
        withAnimation(.easeOut(duration: 0.3)) { 
            showCard = true 
        }
    }

    private func toggleExpanded() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            expanded.toggle()
            drag = 0
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.25)) { 
            showCard = false 
        }
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

private let qrImageContext = CIContext()

func makeQR(from string: String) -> UIImage {
    guard !string.isEmpty else { return UIImage() }
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    if let image = renderQR(filter.outputImage) { return image }
    filter.correctionLevel = "L"
    return renderQR(filter.outputImage) ?? UIImage()
}

private func renderQR(_ output: CIImage?) -> UIImage? {
    guard let output, !output.extent.isEmpty else { return nil }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cg = qrImageContext.createCGImage(scaled, from: scaled.extent) else { return nil }
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
        
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.white, Color(hex: "169402"))
            Text("Успешно")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
        
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 580, height: 580)
        
        Text("Покажите QR-код")
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(Color(white: 0.45))
            .multilineTextAlignment(.center)

        if !caption.isEmpty {
            Text(caption.uppercased())
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
        }

        VStack(spacing: 2) {
            Text(dateString)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(.black)

            Text("Сумма 80 ₸")
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

func densePayload(_ input: String, level: Int) -> String {
    let link = input.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard level > 0, !link.isEmpty else { return link }

    let target = level == 1 ? 60 : 120
    
    if link.utf8.count >= target {
        return link
    }

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
