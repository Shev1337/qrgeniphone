import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation
import VisionKit

// MARK: - Модель данных
struct SavedItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var link: String
    var caption: String
    var title: String = ""
    var date: Date = Date()

    enum CodingKeys: String, CodingKey { case id, link, caption, title, date }

    init(link: String, caption: String, title: String, date: Date = Date()) {
        self.link = link
        self.caption = caption
        self.title = title
        self.date = date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        link = (try? c.decode(String.self, forKey: .link)) ?? ""
        caption = (try? c.decode(String.self, forKey: .caption)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        date = (try? c.decode(Date.self, forKey: .date)) ?? Date()
    }
}

// MARK: - Главное представление
struct ContentView: View {
    @AppStorage("savedLink") private var link = ""
    @AppStorage("savedCaption") private var caption = ""
    @AppStorage("savedTitle") private var title = ""
    @AppStorage("savedItems") private var savedData = ""
    @AppStorage("density") private var density = 0

    @State private var ticket: (item: SavedItem, image: UIImage)?
    @State private var showQRCodeError = false
    @State private var showScanner = false
    @State private var originalBrightness: CGFloat = 1.0

    // Состояния для подтверждения отсканированного QR и выбора текста
    @State private var showConfirmSheet = false
    @State private var scannedLinkToConfirm = ""
    @State private var confirmedCaption = ""
    @State private var confirmedTitle = ""
    @State private var detectedTexts: [String] = []

    // История уже сгенерированных QR
    @State private var showHistory = false

    // Состояния для меню действий и редактирования сохранённых
    @State private var selectedItemForAction: SavedItem? = nil
    @State private var showActionSheet = false
    @State private var showEditModal = false
    @State private var editingItem: SavedItem? = nil
    @State private var editCaption = ""
    @State private var editTitle = ""

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

    var body: some View {
        ZStack(alignment: .top) {
            Color.white.ignoresSafeArea()
            form
                .blur(radius: ticket == nil ? 0 : 5)
                .accessibilityHidden(ticket != nil)
                .allowsHitTesting(ticket == nil)

            if let ticket {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture(perform: close)
                    .accessibilityHidden(true)
                    .transition(.opacity)
                    .zIndex(1)

                ScrollView {
                    DemoTicketView(item: ticket.item, qrImage: ticket.image, onClose: close)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                }
                .frame(maxWidth: 448)
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .preferredColorScheme(.light)
        .alert("Не удалось создать QR-код", isPresented: $showQRCodeError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Проверьте данные или сократите строку.")
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { scannedString, texts in
                showScanner = false
                handleScannedResult(link: scannedString, texts: texts)
            }
        }
        // Шторка подтверждения с возможностью выбора распознанного текста
        .sheet(isPresented: $showConfirmSheet) {
            NavigationView {
                VStack(spacing: 16) {
                    Text("Отсканирован QR-код")
                        .font(.headline)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Данные QR-кода:")
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                        Text(scannedLinkToConfirm)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.black)
                            .lineLimit(2)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Если камера поймала несколько текстов — показываем их для выбора
                    if !detectedTexts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Выберите нужную надпись с экрана:")
                                .font(.footnote)
                                .foregroundColor(Color(white: 0.5))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(detectedTexts, id: \.self) { candidate in
                                        Button {
                                            confirmedCaption = candidate.uppercased()
                                        } label: {
                                            Text(candidate)
                                                .font(.system(size: 14, weight: .medium))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(confirmedCaption == candidate.uppercased() ? Color.black : Color(white: 0.92))
                                                .foregroundColor(confirmedCaption == candidate.uppercased() ? .white : .black)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Номер транспорта или подпись")
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                        TextField("Номер транспорта или подпись", text: $confirmedCaption)
                            .textInputAutocapitalization(.characters)
                            .padding()
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Маршрут или название")
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.5))
                        TextField("Маршрут или название", text: $confirmedTitle)
                            .padding()
                            .background(Color(white: 0.95))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Spacer()
                }
                .padding(20)
                .navigationTitle("Подтверждение вывода")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") {
                            showConfirmSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Вывести") {
                            link = scannedLinkToConfirm
                            caption = confirmedCaption
                            title = confirmedTitle
                            let item = SavedItem(
                                link: link,
                                caption: caption,
                                title: title,
                                date: items.first(where: { $0.link == link })?.date ?? Date()
                            )
                            saveItem(item)
                            showConfirmSheet = false
                            openCard(for: item)
                        }
                        .bold()
                    }
                }
            }
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
                    TextField("Номер транспорта или подпись", text: $editCaption)
                        .textInputAutocapitalization(.characters)
                        .padding()
                        .background(Color(white: 0.95))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    TextField("Маршрут или название", text: $editTitle)
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
        .onChange(of: ticket != nil) { isOpen in
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
        link = item.link
        caption = item.caption
        title = item.title

        saveItem(item)
        openCard(for: item)
    }

    // MARK: - Обработка сканирования с выбором текстов

    private func handleScannedResult(link scannedLink: String, texts: [String]) {
        scannedLinkToConfirm = scannedLink
        detectedTexts = texts
        
        // 1. Проверяем историю
        if let existingItem = items.first(where: { $0.link == scannedLink }) {
            confirmedCaption = existingItem.caption
            confirmedTitle = existingItem.title
        } 
        // 2. Если есть распознанные тексты с камеры, берем первый (самый точный/близкий) по умолчанию
        else if let firstText = texts.first {
            confirmedCaption = firstText.uppercased()
            confirmedTitle = title
        } 
        // 3. Иначе берем то, что введено в поле
        else {
            confirmedCaption = caption
            confirmedTitle = title
        }
        
        showConfirmSheet = true
    }

    // MARK: - Главный экран

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("QR-генератор")
                .font(.largeTitle.bold())
                .foregroundColor(.black)
                .padding(.top, 24)

            HStack(spacing: 8) {
                TextField("Ссылка на сайт", text: $link)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 22, weight: .medium))
                        .frame(width: 52, height: 52)
                        .background(Color(white: 0.95))
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }

            TextField("Маршрут или название", text: $title)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            TextField("Номер транспорта или подпись", text: $caption)
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
                    openCard(for: SavedItem(link: link, caption: caption, title: title))
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
                    saveItem(SavedItem(link: link, caption: caption, title: title))
                } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 56, height: 52)
                        .background(Color(white: 0.95))
                        .foregroundColor(link.isEmpty ? Color(white: 0.7) : .black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(link.isEmpty)

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

    private func saveItem(_ item: SavedItem) {
        var list = items
        list.removeAll { $0.link == item.link }
        list.insert(item, at: 0)
        setItems(list)
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
                Image(uiImage: makeQR(from: item.link))
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

    private func openCard(for item: SavedItem) {
        hideKeyboard()

        let separator = item.link.contains("?") ? "&" : "?"
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let payload = "\(item.link)\(separator)rnd=\(timestamp)"
        let image = makeQR(from: densePayload(payload, level: density))
        guard image.cgImage != nil else {
            showQRCodeError = true
            return
        }

        withAnimation(.easeOut(duration: 0.25)) {
            ticket = (item: item, image: image)
        }
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.20)) {
            ticket = nil
        }
    }
}

// MARK: - Надежный сканер QR + текста с долгой стабилизацией

struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String, [String]) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr]), .text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onScan: (String, [String]) -> Void
        var hasScanned = false

        init(onScan: @escaping (String, [String]) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            
            // Задержка 1.5 секунды: камера успевает идеально сфокусироваться и распознать текст
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                guard !self.hasScanned else { return }
                
                var foundQrPayload: String? = nil
                var qrCenterY: CGFloat = 0
                
                for item in allItems {
                    if case let .barcode(code) = item, let payload = code.payloadStringValue {
                        foundQrPayload = payload
                        qrCenterY = (code.bounds.bottomRight.y + code.bounds.topLeft.y) / 2
                        break
                    }
                }
                
                guard let payload = foundQrPayload else { return }
                
                var textCandidates: [(text: String, distance: CGFloat)] = []
                
                for item in allItems {
                    if case let .text(textObj) = item {
                        let textString = textObj.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !textString.isEmpty, textString.count < 30 else { continue }
                        
                        let textCenterY = (textObj.bounds.bottomRight.y + textObj.bounds.topLeft.y) / 2
                        let distance = abs(qrCenterY - textCenterY)
                        
                        if distance < 350 {
                            textCandidates.append((text: textString, distance: distance))
                        }
                    }
                }
                
                textCandidates.sort { $0.distance < $1.distance }
                
                var uniqueTexts: [String] = []
                for candidate in textCandidates {
                    if !uniqueTexts.contains(candidate.text) {
                        uniqueTexts.append(candidate.text)
                    }
                }
                
                self.hasScanned = true
                DispatchQueue.main.async {
                    self.onScan(payload, uniqueTexts)
                }
            }
        }
    }
}

func makeQR(from string: String) -> UIImage {
    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let output = filter.outputImage else { return UIImage() }
    let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
    guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return UIImage() }
    return UIImage(cgImage: cg)
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
