import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var link = ""
    @State private var caption = ""
    @State private var showCard = false

    private let backdrop = Color(red: 0.85, green: 0.86, blue: 0.88)

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
                .padding()
                .background(Color(white: 0.95))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

            Spacer()
        }
        .padding(.horizontal, 20)
    }

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
                Text(caption)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 12)

            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(caption.isEmpty ? "QR-код" : caption, image: Image(uiImage: image))
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
