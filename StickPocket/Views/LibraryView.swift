import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @EnvironmentObject private var store: StickerStore
    @State private var search = ""
    @State private var filter = 0
    @State private var showImport = false
    @State private var showInfo = false
    @State private var notice: Notice?

    private var filtered: [Sticker] {
        store.stickers.filter {
            (filter != 1 || $0.favorite) && (filter != 2 || $0.isAnimated) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("LA TUA RACCOLTA").font(.caption.weight(.bold)).tracking(2)
                                .foregroundStyle(Palette.lime)
                            Text("Piccoli sticker.\nGrandi reazioni.")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "face.smiling.inverse")
                            .font(.system(size: 42)).foregroundStyle(Palette.lime)
                            .rotationEffect(.degrees(12)).accessibilityHidden(true)
                    }
                    Button { showImport = true } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Aggiungi sticker").font(.headline)
                                Text("Da TikTok, Foto o File").font(.caption)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.headline)
                        }.foregroundStyle(.black).padding(20)
                            .background(Palette.lime, in: RoundedRectangle(cornerRadius: 24))
                    }.buttonStyle(.plain)

                    Picker("Mostra", selection: $filter) {
                        Text("Tutti").tag(0)
                        Text("Preferiti").tag(1)
                        Text("Animati").tag(2)
                    }.pickerStyle(.segmented)

                    if let error = store.loadError {
                        ContentUnavailableView("Raccolta non disponibile", systemImage: "externaldrive.badge.exclamationmark",
                                               description: Text(error))
                    } else if filtered.isEmpty {
                        ContentUnavailableView(
                            store.stickers.isEmpty ? "Il primo sticker ti aspetta" : "Nessuno sticker qui",
                            systemImage: store.stickers.isEmpty ? "square.stack.3d.up" : "magnifyingglass",
                            description: Text(store.stickers.isEmpty
                                ? "Aggiungi quelli che vuoi ritrovare al volo. Restano su questo iPhone."
                                : "Prova un altro filtro o cambia la ricerca."))
                    } else {
                        HStack {
                            Text("\(filtered.count) sticker").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "iphone").foregroundStyle(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                            ForEach(filtered) { item in
                                NavigationLink {
                                    StickerDetailView(stickerID: item.id)
                                } label: { StickerCard(item: item) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(item.favorite ? "Togli dai preferiti" : "Aggiungi ai preferiti",
                                               systemImage: item.favorite ? "star.slash" : "star") {
                                            do { try store.toggleFavorite(item) }
                                            catch { notice = Notice(title: "Non salvato", message: error.localizedDescription) }
                                        }
                                    }
                            }
                        }
                    }
                }.padding(20)
            }
            .background(Palette.background)
            .navigationTitle("StickPocket")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Cerca nella raccolta")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Informazioni", systemImage: "info.circle") { showInfo = true }
                }
            }
            .sheet(isPresented: $showImport) { ImportView() }
            .sheet(isPresented: $showInfo) { InfoView() }
            .alert(item: $notice) { Alert(title: Text($0.title), message: Text($0.message)) }
        }
    }
}

private struct StickerCard: View {
    @EnvironmentObject private var store: StickerStore
    let item: Sticker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.045))
                if let image = store.thumbnail(for: item) {
                    Image(uiImage: image).resizable().scaledToFit().padding(20)
                } else {
                    Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if item.favorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(Palette.lime).padding(10)
                }
            }.frame(height: 132)
            Text(item.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            HStack {
                Text(item.origin.label)
                Spacer(minLength: 2)
                if item.isAnimated { Text("ANIMATO").font(.system(size: 9, weight: .heavy)).foregroundStyle(Palette.lime) }
            }.font(.caption).foregroundStyle(.secondary)
        }.padding(12).background(Palette.card, in: RoundedRectangle(cornerRadius: 26))
            .accessibilityElement(children: .combine)
    }
}

struct ImportView: View {
    @EnvironmentObject private var store: StickerStore
    @Environment(\.dismiss) private var dismiss
    @State private var selection: [PhotosPickerItem] = []
    @State private var filePicker = false
    @State private var browser: BrowserDestination?
    @State private var notice: Notice?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { browser = .comments } label: {
                        Label("Dai commenti TikTok", systemImage: "bubble.left.and.bubble.right")
                    }
                    Button { browser = .messages } label: {
                        Label("Dai miei messaggi", systemImage: "paperplane")
                    }
                } header: { Text("Apri e scegli") } footer: {
                    Text("Apri il video o la tua chat, poi cerca le immagini visibili. TikTok potrebbe limitare l’accesso o il salvataggio.")
                }
                Section {
                    PhotosPicker(selection: $selection, maxSelectionCount: 20, matching: .images,
                                 preferredItemEncoding: .current) {
                        Label("Scegli da Foto", systemImage: "photo.on.rectangle")
                    }
                    Button { filePicker = true } label: {
                        Label("Importa da File", systemImage: "folder")
                    }
                } header: { Text("Già sul tuo iPhone") } footer: {
                    Text("Importa un’immagine originale o uno screenshot. Puoi ritagliare le immagini ferme dopo averle salvate.")
                }
                if busy { HStack { ProgressView(); Text("Importazione…") } }
            }
            .disabled(busy)
            .navigationTitle("Aggiungi sticker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
            .fullScreenCover(item: $browser) { TikTokBrowserView(destination: $0) }
            .onChange(of: selection) { _, items in
                guard !items.isEmpty else { return }
                Task { await importPhotos(items) }
            }
            .fileImporter(isPresented: $filePicker, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
                Task { await importFiles(result) }
            }
            .alert(item: $notice) { Alert(title: Text($0.title), message: Text($0.message)) }
        }
    }

    @MainActor private func importPhotos(_ items: [PhotosPickerItem]) async {
        busy = true
        defer { busy = false; selection = [] }
        var added = 0, duplicates = 0, errors: [String] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { throw PocketError.invalidImage }
                let result = try store.add(data: data, name: "Il mio sticker", origin: .photos)
                if result.duplicate { duplicates += 1 } else { added += 1 }
            } catch { errors.append(error.localizedDescription) }
        }
        report(added: added, duplicates: duplicates, errors: errors)
    }

    @MainActor private func importFiles(_ result: Result<[URL], Error>) async {
        busy = true
        defer { busy = false }
        var added = 0, duplicates = 0, errors: [String] = []
        do {
            for url in try result.get().prefix(20) {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    // NSFileCoordinator supports Files providers whose bytes need materialization.
                    var coordinationError: NSError?
                    var readResult: Result<Data, Error>?
                    NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges,
                                                   error: &coordinationError) { readable in
                        readResult = Result {
                            let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                            guard size <= MediaRules.maxBytes else { throw PocketError.tooLarge }
                            return try Data(contentsOf: readable, options: .mappedIfSafe)
                        }
                    }
                    if let coordinationError { throw coordinationError }
                    guard let readResult else { throw PocketError.invalidImage }
                    let data = try readResult.get()
                    let result = try store.add(data: data, name: url.deletingPathExtension().lastPathComponent, origin: .files)
                    if result.duplicate { duplicates += 1 } else { added += 1 }
                } catch { errors.append(error.localizedDescription) }
            }
        } catch { errors.append(error.localizedDescription) }
        report(added: added, duplicates: duplicates, errors: errors)
    }

    private func report(added: Int, duplicates: Int, errors: [String]) {
        var message = "\(added) aggiunti · \(duplicates) già presenti."
        if let first = errors.first { message += "\n\(errors.count) non importati: \(first)" }
        notice = Notice(title: errors.isEmpty ? "Raccolta aggiornata" : "Importazione completata in parte", message: message)
    }
}
