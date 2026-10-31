import SwiftUI
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var link = ""
    @State private var caption = ""
    @State private var showSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Ссылка на сайт", text: $link)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Подпись под QR-кодом", text: $caption)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    showSheet = true
                } label: {
                    Text("Создать QR-код")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(link.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(link.isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("QR-генератор")
            .sheet(isPresented: $showSheet) {
                ResultView(link: link, caption: caption)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

struct ResultView: View {
    let link: String
    let caption: String

    var body: some View {
        let image = makeQR(from: link)
        VStack(spacing: 16) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 260, maxHeight: 260)
                .padding(.top, 24)

            if !caption.isEmpty {
                Text(caption)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            }

            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview(caption.isEmpty ? "QR-код" : caption, image: Image(uiImage: image))
            ) {
                Label("Поделиться / Сохранить", systemImage: "square.and.arrow.up")
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
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
