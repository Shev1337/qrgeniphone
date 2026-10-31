import SwiftUI
import CoreImage.CIFilterBuiltins

struct SavedItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var link: String
    var caption: String
}

struct ContentView: View {
    @AppStorage("savedLink") private var link = ""
    @AppStorage("savedCaption") private var caption = ""
    @AppStorage("savedItems") private var savedData = ""
    @State private var showCard = false

    private let backdrop = Color(red: 0.85, green: 0.86, blue: 0.88)

    private var items: [SavedItem] {
        get { (try? JSONDecoder().decode([SavedItem].self, from: Data(savedData.utf8))) ?? [] }
    }

    private func setItems(_ new: [SavedItem]) {
        if let data = try? JSONEncoder().encode(new),
           let str = String(data: data, encoding: .utf8) {
            savedData = str
        }
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

                    card(height: geo.size.height * 0.62)
                        .transition(.move(edge: .bottom))
                        .zIndex(2)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Главный экран

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            TextField("Подпись под QR-кодом", text: $caption)
                .textInputAutocapitalization(.characters)
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            HStack(spacing: 12) {
                Button {
                    hideKeyboard()
                    withAnimation(.easeOut(duration: 0.3)) { showCard = true }
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
        HStack(spacing: 12) {
            Button {
                link = item.link
                caption = item.caption
                hideKeyboard()
                withAnimation(.easeOut(duration: 0.3)) { showCard = true }
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.caption.isEmpty ? item.link : item.caption.uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    if !item.caption.isEmpty {
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
        let new = SavedItem(link: link, caption: caption)
        var list = items
        // не сохраняем дубликаты
        list.removeAll { $0.link == new.link && $0.caption == new.caption }
        list.insert(new, at: 0)
        setItems(list)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // MARK: - Карточка с QR

    private func card(height: CGFloat) -> some View {
        let image = makeQR(from: link)
        return VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { close() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                        .padding(8)
                }
            }
            .padding(.top, 10)

            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 270, maxHeight: 270)
                .padding(12)
                .background(Color.white)
                .padding(.top, 4)

            if !caption.isEmpty {
                Text(caption.uppercased())
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 12)

            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(caption.isEmpty ? "QR-код" : caption.uppercased(), image: Image(uiImage: image))
            ) {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                    Text("Поделиться")
                        .font(.footnote)
                }
                .foregroundColor(.black)
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(
            TopRounded(radius: 28)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.12), radius: 12, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
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
