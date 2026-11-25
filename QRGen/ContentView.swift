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
    @State private var showServices = false
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
    @State private var confirmClearHistory = false

    private let collapsedRatio: CGFloat = 0.82

    private var items: [SavedItem] {
        ((try? JSONDecoder().decode([SavedItem].self, from: Data(savedData.utf8))) ?? []).inHistoryOrder()
    }

    private func setItems(_ new: [SavedItem]) {
        if let data = try? JSONEncoder().encode(new),
           let str = String(data: data, encoding: .utf8) {
            savedData = str
        }
    }

    private func togglePin(_ id: UUID) {
        var list = items
        if let index = list.firstIndex(where: { $0.id == id }) {
            list[index].togglePin()
            setItems(list)
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "Дата создания не сохранена" }
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
                if showServices {
                    form
                } else {
                    StartScreen(
                        onScan: beginScan,
                        onServices: { showServices = true },
                        onHistory: { showHistory = true }
                    )
                }

                if showCard, let ticket = currentTicket, let image = currentQR {
                    ZStack(alignment: .top) {
                        Brand.blush
                            .ignoresSafeArea()
                            .onTapGesture { close() }

                        VStack(spacing: 8) {
                            Text("Билет Avtobys. Оплата проезда")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Brand.ink)
                                .padding(.top, 6)

                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundStyle(Color.white, Brand.success)
                                Text("Ваш платеж принят")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Brand.ink)
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
        .tint(Brand.coral)
        .sheet(isPresented: $showScanner) {
            ScanFlowSheet(initialTitle: title) { ticket, image in
                openCard(ticket, image: image, recordCreation: true)
            }
        }
        .alert("QRArest", isPresented: $showError) {
            Button("ОК", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showHistory) {
            historySheet
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

    private func openSaved(_ item: SavedItem) {
        hideKeyboard()
        showHistory = false
        openCard(item)
    }

    private func repeatSaved(_ item: SavedItem) {
        hideKeyboard()
        showHistory = false
        let ticket = item.repeated { densePayload($0, level: density) }
        openCard(ticket, recordCreation: true)
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

    // MARK: - Сервисы

    private var form: some View {
        let recent = items.prefix(3)
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    hideKeyboard()
                    showServices = false
                } label: {
                    Label("Главная", systemImage: "chevron.backward")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Brand.burgundy)
                        .padding(.horizontal, 13)
                        .frame(minHeight: 44)
                        .background(.white, in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("На главный экран")
                .accessibilityIdentifier("services.back")

                Text("QR-генератор")
                    .font(.system(.largeTitle, design: .serif, weight: .medium))
                    .foregroundStyle(Brand.ink)
                    .accessibilityAddTraits(.isHeader)

                serviceFields

                VStack(alignment: .leading, spacing: 8) {
                    Button(action: openHistory) {
                        HStack {
                            Label("История чеков", systemImage: "clock")
                                .font(.headline)
                                .foregroundStyle(Brand.ink)
                            Spacer(minLength: 10)
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Brand.burgundy)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("history.open.services")

                    ForEach(recent) { item in
                        row(item)
                    }
                }
            }
            .frame(maxWidth: 550, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { Brand.paper.ignoresSafeArea() }
    }

    private var serviceFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            serviceField("Данные QR-кода") {
                HStack(spacing: 8) {
                    TextField("Ссылка или текст", text: Binding(
                        get: { link },
                        set: { value in
                            if value != link { sourceLink = nil }
                            link = value
                        }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .foregroundStyle(Brand.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minHeight: 48)
                    .background(Brand.paper, in: RoundedRectangle(cornerRadius: 12))

                    Button(action: beginScan) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Brand.burgundy)
                            .frame(width: 48, height: 48)
                            .background(Brand.blush, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Сканировать QR-код")
                    .accessibilityIdentifier("scan.open")
                }
            }

            serviceField("Номер автобуса") {
                BusNumberField(text: $caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minHeight: 48)
                    .background(Brand.paper, in: RoundedRectangle(cornerRadius: 12))
            }

            serviceField("Текст на чеке") {
                TextField("Необязательно", text: $title)
                    .accessibilityLabel("Текст на чеке")
                    .foregroundStyle(Brand.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minHeight: 48)
                    .background(Brand.paper, in: RoundedRectangle(cornerRadius: 12))
            }

            serviceField("Плотность QR-кода") {
                Picker("Плотность QR-кода", selection: $density) {
                    Text("Обычная").tag(0)
                    Text("Плотная").tag(1)
                    Text("Максимум").tag(2)
                }
                .pickerStyle(.segmented)

                if density > 0 && !link.isEmpty {
                    Text("В коде: \(sourceLink == link ? link : densePayload(link, level: density))")
                        .font(.caption2)
                        .foregroundStyle(Brand.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            HStack(spacing: 8) {
                Button {
                    saveCurrent(open: true)
                } label: {
                    Text("Создать QR-код")
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(canGenerate ? .white : Brand.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(canGenerate ? Brand.burgundy : Brand.blush, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .disabled(!canGenerate)

                Button {
                    hideKeyboard()
                    saveCurrent()
                } label: {
                    Image(systemName: "bookmark")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(canGenerate ? Brand.burgundy : Brand.outline)
                        .frame(width: 50, height: 50)
                        .background(Brand.blush, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Сохранить чек")
                .disabled(!canGenerate)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Brand.line)
                .allowsHitTesting(false)
        }
    }

    private func serviceField<Content: View>(
        _ label: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Brand.muted)
            content()
        }
    }

    private func row(_ item: SavedItem) -> some View {
        let primary = !item.caption.isEmpty ? item.caption.uppercased()
            : (!item.title.isEmpty ? item.title : item.link)

        return HStack(spacing: 12) {
            Button {
                openSaved(item)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: item.pinnedAt == nil ? "doc.text" : "pin.fill")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Brand.burgundy)
                        .frame(width: 40, height: 40)
                        .background(Brand.blush, in: RoundedRectangle(cornerRadius: 11))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(primary)
                            .font(.headline)
                            .foregroundStyle(Brand.ink)
                            .lineLimit(1)
                        Text(formattedDate(item.date))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Brand.muted)
                        if primary != item.link {
                            Text(item.link)
                                .font(.caption)
                                .foregroundStyle(Brand.muted)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(item.pinnedAt == nil ? "" : "Закреплён")
            .accessibilityHint("Открывает чек с исходным временем")

            Menu {
                Button { openSaved(item) } label: {
                    Label("Открыть оригинал", systemImage: "doc.text")
                }
                Button { repeatSaved(item) } label: {
                    Label("Повторить с текущим временем", systemImage: "arrow.clockwise")
                }
                Button { togglePin(item.id) } label: {
                    Label(
                        item.pinnedAt == nil ? "Закрепить" : "Открепить",
                        systemImage: item.pinnedAt == nil ? "pin" : "pin.slash"
                    )
                }
                Button {
                    fillForm(from: item)
                    showServices = true
                    showHistory = false
                } label: {
                    Label("Изменить копию", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteItem(item.id)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Brand.burgundy)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Действия с чеком")
        }
        .padding(.leading, 12)
        .padding(.trailing, 5)
        .padding(.vertical, 11)
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Brand.line)
                .allowsHitTesting(false)
        }
    }

    private func saveCurrent(open: Bool = false) {
        guard canGenerate else { return }
        let fromScan = sourceLink == link
        let input = fromScan ? link : link.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = normalizeBusNumber(caption) ?? caption.uppercased()
        let ticket = SavedItem(link: input, caption: number, title: title, fromScan: fromScan)
            .repeated { densePayload($0, level: density) }
        if open {
            openCard(ticket, recordCreation: true)
        } else {
            guard makeQR(from: ticket.payload).cgImage != nil else {
                presentError("Эти данные не помещаются в QR-код чека.")
                return
            }
            setItems(ticket.addedToHistory(items))
        }
    }

    // MARK: - История

    private func openHistory() {
        hideKeyboard()
        showHistory = true
    }

    private var historySheet: some View {
        let history = items
        let pinned = history.filter { $0.pinnedAt != nil }
        let unpinned = history.filter { $0.pinnedAt == nil }

        return NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.title2.weight(.medium))
                            .foregroundStyle(Brand.burgundy)
                            .frame(width: 54, height: 54)
                            .background(Brand.blush, in: RoundedRectangle(cornerRadius: 16))
                            .accessibilityHidden(true)
                        Text("История пока пуста")
                            .font(.headline)
                            .foregroundStyle(Brand.ink)
                        Text("Здесь появятся созданные чеки")
                            .font(.subheadline)
                            .foregroundStyle(Brand.muted)
                    }
                    .multilineTextAlignment(.center)
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if !pinned.isEmpty {
                            historySection("Закреплённые", receipts: pinned)
                        }
                        if !unpinned.isEmpty {
                            historySection(pinned.isEmpty ? "Все чеки" : "Остальные чеки", receipts: unpinned)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: 590)
                    .frame(maxWidth: .infinity)
                }
            }
            .background { Brand.paper.ignoresSafeArea() }
            .navigationTitle("История чеков")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Brand.paper, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { showHistory = false }
                }
                if !history.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                confirmClearHistory = true
                            } label: {
                                Label("Очистить историю", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Действия с историей")
                    }
                }
            }
            .confirmationDialog("Удалить все чеки из истории?", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                Button("Удалить все чеки", role: .destructive) { setItems([]) }
                Button("Отмена", role: .cancel) {}
            }
        }
        .tint(Brand.burgundy)
    }

    private func historySection(_ title: String, receipts: [SavedItem]) -> some View {
        Section {
            ForEach(receipts) { item in
                row(item)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteItem(item.id)
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Brand.muted)
                .textCase(nil)
        }
    }

    private func deleteItem(_ id: UUID) {
        setItems(items.filter { $0.id != id })
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
                .fill(Brand.outline)
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
                        .foregroundColor(Brand.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Spacer()
                }
                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Brand.ink)
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
                .foregroundColor(Brand.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.top, 32)
                .padding(.horizontal, 16)

            if !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.system(size: lerp(16, 22, t), weight: .bold))
                    .foregroundColor(Brand.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 24)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 2) {
                Text(currentDateString)
                    .font(.system(size: lerp(12, 14, t), weight: .regular))
                    .foregroundColor(Brand.ink)

                Text("Сумма 80 ₸")
                    .font(.system(size: lerp(12, 14, t), weight: .light))
                    .foregroundColor(Brand.ink)
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
                    .foregroundColor(Brand.ink)
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
                    .foregroundColor(Brand.ink)
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

    private func fillForm(from ticket: SavedItem) {
        link = ticket.link
        caption = ticket.caption
        title = ticket.title
        sourceLink = ticket.fromScan ? ticket.link : nil
    }

    private func openCard(_ ticket: SavedItem, image: UIImage? = nil, recordCreation: Bool = false) {
        let qr = image ?? makeQR(from: ticket.payload)
        guard qr.cgImage != nil else {
            presentError("Эти данные не помещаются в QR-код чека.")
            return
        }
        hideKeyboard()
        if recordCreation { setItems(ticket.addedToHistory(items)) }
        fillForm(from: ticket)
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
                .foregroundColor(Brand.ink)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.white, Brand.success)
            Text("Успешно")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Brand.ink)
        }
        
        Image(uiImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: 580, height: 580)
        
        Text("Покажите QR-код")
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(Brand.muted)
            .multilineTextAlignment(.center)

        if !caption.isEmpty {
            Text(caption.uppercased())
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Brand.ink)
                .multilineTextAlignment(.center)
        }

        VStack(spacing: 2) {
            Text(dateString)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(Brand.ink)

            Text("Сумма 80 ₸")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Brand.ink)
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
