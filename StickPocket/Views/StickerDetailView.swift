import SwiftUI
import WebKit
import Photos

struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct CropPayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let name: String
}

struct StickerDetailView: View {
    @EnvironmentObject private var store: StickerStore
    @Environment(\.dismiss) private var dismiss
    let stickerID: UUID
    @State private var data: Data?
    @State private var notice: Notice?
    @State private var share: SharePayload?
    @State private var crop: CropPayload?
    @State private var rename = false
    @State private var newName = ""
    @State private var delete = false
    @State private var savingPhoto = false

    private var item: Sticker? { store.stickers.first { $0.id == stickerID } }

    var body: some View {
        Group {
            if let item {
                ScrollView {
                    VStack(spacing: 24) {
                        if let data {
                            OriginalPreview(data: data, mime: item.mime)
                                .frame(height: 310)
                                .clipShape(RoundedRectangle(cornerRadius: 30))
                        } else {
                            ContentUnavailableView("Anteprima non disponibile", systemImage: "photo")
                                .frame(height: 260)
                        }
                        VStack(spacing: 8) {
                            Text(item.name).font(.title2.bold()).multilineTextAlignment(.center)
                            Text("\(item.origin.label) · \(item.width) × \(item.height)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if item.isAnimated {
                                Label("Originale animato", systemImage: "play.circle")
                                    .font(.caption.weight(.bold)).foregroundStyle(Palette.lime)
                            }
                        }
                        Button { share = SharePayload(url: store.fileURL(for: item)) } label: {
                            Label("Condividi originale", systemImage: "square.and.arrow.up")
                                .font(.headline).frame(maxWidth: .infinity).padding(18)
                                .background(Palette.lime, in: Capsule()).foregroundStyle(.black)
                        }.disabled(data == nil)
                        HStack(spacing: 12) {
                            action(item.favorite ? "Preferito" : "Preferiti",
                                   symbol: item.favorite ? "star.fill" : "star") {
                                do { try store.toggleFavorite(item) }
                                catch { show(error) }
                            }
                            action("Rinomina", symbol: "pencil") { newName = item.name; rename = true }
                            if !item.isAnimated {
                                action("Ritaglia", symbol: "crop") {
                                    if let data, let image = UIImage(data: data) {
                                        crop = CropPayload(image: image, name: item.name)
                                    }
                                }
                            }
                        }
                        Button {
                            Task { await saveToPhotos(item) }
                        } label: {
                            if savingPhoto { ProgressView() }
                            else { Label("Salva anche in Foto", systemImage: "photo.badge.arrow.down") }
                        }.disabled(savingPhoto || data == nil)
                        Text("La condivisione invia il file originale. L’app che lo riceve decide come mostrarlo.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.padding(22)
                }.background(Palette.background)
            } else { ContentUnavailableView("Sticker non disponibile", systemImage: "photo") }
        }
        .navigationTitle("Il tuo sticker").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Elimina", systemImage: "trash", role: .destructive) { delete = true }
                    .disabled(item == nil)
            }
        }
        .task(id: stickerID) {
            guard let item else { return }
            do { data = try store.data(for: item) }
            catch { show(error) }
        }
        .sheet(item: $share) { ShareSheet(url: $0.url) }
        .sheet(item: $crop) { CropEditor(image: $0.image, originalName: $0.name) }
        .alert("Rinomina sticker", isPresented: $rename) {
            TextField("Nome", text: $newName)
            Button("Annulla", role: .cancel) {}
            Button("Salva") {
                guard let item else { return }
                do { try store.rename(item, to: newName) }
                catch { show(error) }
            }
        }
        .confirmationDialog("Eliminare questo sticker dalla raccolta?", isPresented: $delete, titleVisibility: .visible) {
            Button("Elimina sticker", role: .destructive) {
                guard let item else { return }
                do { try store.remove(item); dismiss() }
                catch { show(error) }
            }
            Button("Annulla", role: .cancel) {}
        } message: { Text("Le copie già salvate in Foto o condivise rimangono disponibili.") }
        .alert(item: $notice) { Alert(title: Text($0.title), message: Text($0.message)) }
    }

    private func action(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption)
            }.frame(maxWidth: .infinity).padding(.vertical, 18)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }

    @MainActor private func saveToPhotos(_ item: Sticker) async {
        savingPhoto = true
        defer { savingPhoto = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            notice = Notice(title: "Foto non autorizzate",
                            message: "Puoi consentire il salvataggio in Foto dalle impostazioni di iPhone, oppure usare Condividi.")
            return
        }
        do {
            let url = store.fileURL(for: item)
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, fileURL: url, options: nil)
            }
            notice = Notice(title: "Salvato in Foto", message: "Lo sticker è stato aggiunto alla tua galleria.")
        } catch { show(error) }
    }

    private func show(_ error: Error) {
        notice = Notice(title: "Operazione non riuscita", message: error.localizedDescription)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct OriginalPreview: View {
    let data: Data
    let mime: String

    var body: some View {
        Group {
            if ["image/heic", "image/heif"].contains(mime), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Palette.card)
            } else {
                WebOriginalPreview(data: data, mime: mime)
            }
        }
    }
}

private struct WebOriginalPreview: UIViewRepresentable {
    let data: Data
    let mime: String

    final class Coordinator {
        var lastData: Data?
        var lastMIME: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.isScrollEnabled = false
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = true
        view.accessibilityLabel = "Anteprima dello sticker originale"
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.lastData != data || context.coordinator.lastMIME != mime else { return }
        context.coordinator.lastData = data
        context.coordinator.lastMIME = mime
        let supported = ["image/png", "image/jpeg", "image/gif", "image/webp", "image/heic", "image/heif"]
        let safeMIME = supported.contains(mime) ? mime : "image/png"
        let html = """
        <!doctype html><html><head>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'">
        <style>
        html,body{margin:0;width:100%;height:100%;background:#1b1f21}
        body{display:flex;align-items:center;justify-content:center}
        img{object-fit:contain;max-width:88%;max-height:88%}
        </style></head><body><img alt="" src="data:\(safeMIME);base64,\(data.base64EncodedString())"></body></html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
