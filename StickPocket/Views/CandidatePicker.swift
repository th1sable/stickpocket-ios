import SwiftUI

struct CandidatePicker: View {
    @EnvironmentObject private var store: StickerStore
    @Environment(\.dismiss) private var dismiss
    let candidates: [ImageCandidate]
    let origin: StickerOrigin
    @State private var selected: ImageCandidate?
    @State private var payload: Data?
    @State private var payloadMIME = "image/png"
    @State private var name = ""
    @State private var task: Task<Void, Never>?
    @State private var busy = false
    @State private var notice: Notice?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Tocca l’immagine che vuoi conservare.")
                        .font(.headline)
                    Text("Le immagini visibili possono includere foto e anteprime. Scegli tu lo sticker.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(candidates) { candidate in
                            Button { select(candidate) } label: {
                                CandidateThumbnail(candidate: candidate)
                                    .frame(height: 105).frame(maxWidth: .infinity)
                                    .padding(8)
                                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18)
                                        .stroke(selected?.id == candidate.id ? Palette.lime : Color.clear, lineWidth: 3))
                            }.accessibilityLabel("Immagine \(candidate.id), \(candidate.width) per \(candidate.height)")
                        }
                    }
                    if busy { HStack { ProgressView(); Text("Carico l’originale…") } }
                    if let payload {
                        Text("Anteprima del file originale").font(.headline)
                        OriginalPreview(data: payload, mime: payloadMIME)
                            .frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 22))
                        TextField("Nome dello sticker", text: $name).textFieldStyle(.roundedBorder)
                        Button { save(payload) } label: {
                            Label("Salva nella raccolta", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity).padding(16)
                                .background(Palette.lime, in: Capsule()).foregroundStyle(.black)
                        }.disabled(busy)
                    }
                }.padding(20)
            }.background(Palette.background)
                .navigationTitle("Scegli lo sticker").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
                .alert(item: $notice) { Alert(title: Text($0.title), message: Text($0.message)) }
                .onDisappear { task?.cancel() }
        }
    }

    private func select(_ candidate: ImageCandidate) {
        task?.cancel()
        selected = candidate
        payload = nil
        busy = true
        task = Task { @MainActor in
            do {
                let data = try await MediaDownloader.fetch(candidate)
                try Task.checkCancellation()
                let info = try ImageInspector.inspect(data)
                guard selected?.id == candidate.id else { return }
                payloadMIME = info.mime
                payload = data
                name = "Sticker dai \(origin.label.lowercased())"
                busy = false
            } catch {
                guard !Task.isCancelled, selected?.id == candidate.id else { return }
                busy = false
                notice = Notice(title: "Immagine non disponibile", message: error.localizedDescription)
            }
        }
    }

    private func save(_ data: Data) {
        do {
            let result = try store.add(data: data, name: name, origin: origin)
            notice = Notice(title: result.duplicate ? "Già nella raccolta" : "Sticker salvato",
                            message: result.duplicate ? "Questo file è già presente: \(result.sticker.name)." : "Lo ritrovi nella tua raccolta, anche senza connessione.")
            payload = nil
            selected = nil
        } catch { notice = Notice(title: "Salvataggio non riuscito", message: error.localizedDescription) }
    }
}

private struct CandidateThumbnail: View {
    let candidate: ImageCandidate
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if failed {
                Image(systemName: "photo").foregroundStyle(.secondary)
            } else { ProgressView() }
        }
        .task(id: candidate.src) {
            image = nil
            failed = false
            do {
                // Thumbnails follow the same cookie-free redirect and size policy
                // as the original, with a smaller limit for the scrolling grid.
                let bytes = try await MediaDownloader.fetch(candidate, maxBytes: 4 * 1024 * 1024)
                try Task.checkCancellation()
                let thumbnail = try ImageInspector.inspect(bytes).thumbnail
                image = UIImage(data: thumbnail)
                failed = image == nil
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
        }
    }
}
