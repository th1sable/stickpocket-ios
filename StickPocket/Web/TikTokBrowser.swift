import SwiftUI
import WebKit

enum BrowserDestination: String, Identifiable {
    case comments, messages
    var id: String { rawValue }
    var title: String { self == .comments ? "Dai commenti" : "Dai miei messaggi" }
    var origin: StickerOrigin { self == .comments ? .comments : .messages }
    var url: URL {
        URL(string: self == .comments ? "https://www.tiktok.com/" : "https://www.tiktok.com/messages")!
    }
}

struct ImageCandidate: Codable, Identifiable {
    let id: String
    let src: String
    let width: Int
    let height: Int
    let likelySticker: Bool
    var remoteURL: URL? {
        guard let url = URL(string: src), MediaRules.canDownload(url) else { return nil }
        return url
    }
    var inlineData: Data? {
        guard src.hasPrefix("data:image/"), src.contains(";base64,"),
              let comma = src.firstIndex(of: ",") else { return nil }
        return Data(base64Encoded: String(src[src.index(after: comma)...]))
    }
}

@MainActor
final class TikTokBrowser: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    @Published var loading = false
    @Published var scanning = false
    @Published var host = "www.tiktok.com"
    @Published var canGoBack = false
    @Published var onTikTok = true
    @Published var notice: Notice?
    @Published var candidates: [ImageCandidate] = []
    @Published var showCandidates = false

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
    }

    func open(_ url: URL) {
        guard MediaRules.isTikTok(url) else {
            notice = Notice(title: "Link non valido", message: PocketError.unsupportedLink.localizedDescription)
            return
        }
        candidates = []
        webView.load(URLRequest(url: url))
    }

    func scan() async {
        guard !scanning, let url = webView.url, MediaRules.isTikTok(url) else {
            notice = Notice(title: "Torna a TikTok", message: "La ricerca delle immagini funziona solo nella pagina TikTok che hai aperto.")
            return
        }
        scanning = true
        defer { scanning = false }
        do {
            guard let scriptURL = Bundle.main.url(forResource: "VisibleImages", withExtension: "js") else {
                throw PocketError.noMedia
            }
            let script = try String(contentsOf: scriptURL, encoding: .utf8)
            let value = try await webView.evaluateJavaScript(script, in: nil, contentWorld: .defaultClient)
            guard let text = value as? String, let bytes = text.data(using: .utf8) else { throw PocketError.noMedia }
            // An authentication/navigation change during scan invalidates this result.
            guard webView.url == url else { throw PocketError.noMedia }
            candidates = try JSONDecoder().decode([ImageCandidate].self, from: bytes)
                .filter { $0.remoteURL != nil || $0.inlineData != nil }
            if candidates.isEmpty {
                notice = Notice(title: "Nessuna immagine disponibile",
                    message: "Apri i commenti o la tua chat e porta lo sticker sullo schermo. Se TikTok non lo rende disponibile, importa uno screenshot da Foto.")
            } else {
                showCandidates = true
            }
        } catch {
            notice = Notice(title: "Ricerca non riuscita",
                            message: "Non riesco a leggere le immagini di questa pagina. Ricaricala oppure importa lo sticker da Foto o File.")
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loading = true
        onTikTok = false
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        refresh()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loading = false
        refresh()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    private func fail(_ error: Error) {
        loading = false
        refresh()
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        notice = Notice(title: "Pagina non disponibile",
                        message: "La pagina non si è caricata. Controlla la connessione o usa l’importazione da Foto e File.")
    }

    private func refresh() {
        host = webView.url?.host ?? "TikTok"
        canGoBack = webView.canGoBack
        onTikTok = webView.url.map(MediaRules.isTikTok) ?? false
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        // Authentication is handled by the website. No credential or cookie interception.
        if url.scheme == "https" || url.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
            if navigationAction.targetFrame?.isMainFrame != false {
                notice = Notice(title: "Rimani nella pagina web",
                                message: "Questo pulsante apre un’altra app. Per scegliere uno sticker qui, usa la versione web o importa un file già salvato.")
            }
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, navigationAction.request.url?.scheme == "https" {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

struct WebSurface: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct TikTokBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var browser = TikTokBrowser()
    @State private var link = ""
    @State private var started = false
    let destination: BrowserDestination

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if destination == .comments {
                    HStack {
                        TextField("Incolla il link del video", text: $link)
                            .keyboardType(.URL).textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { openLink() }
                        Button("Apri") { openLink() }.disabled(link.isEmpty)
                    }.padding(12).background(Palette.card)
                }
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                    Text(browser.host).lineLimit(1)
                    Spacer()
                    if browser.loading { ProgressView().controlSize(.small) }
                }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 8)
                WebSurface(webView: browser.webView)
                VStack(spacing: 10) {
                    Text(destination == .comments
                         ? "Apri i commenti e porta lo sticker sullo schermo."
                         : "Accedi su TikTok, apri la tua chat e porta lo sticker sullo schermo.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button {
                        Task { await browser.scan() }
                    } label: {
                        HStack {
                            if browser.scanning { ProgressView().tint(.black) }
                            Image(systemName: "viewfinder")
                            Text("Scegli immagini visibili").fontWeight(.semibold)
                        }.frame(maxWidth: .infinity).padding(14)
                            .background(Palette.lime, in: Capsule()).foregroundStyle(.black)
                    }.disabled(browser.scanning || browser.loading || !browser.onTikTok)
                }.padding(16).background(Palette.background)
            }
            .navigationTitle(destination.title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Indietro", systemImage: "chevron.left") { browser.webView.goBack() }
                        .disabled(!browser.canGoBack)
                    Button("Ricarica", systemImage: "arrow.clockwise") { browser.webView.reload() }
                }
            }
            .onAppear {
                if !started { browser.open(destination.url); started = true }
            }
            .onDisappear { browser.webView.stopLoading() }
            .sheet(isPresented: $browser.showCandidates) {
                CandidatePicker(candidates: browser.candidates, origin: destination.origin)
            }
            .alert(item: $browser.notice) { Alert(title: Text($0.title), message: Text($0.message)) }
        }
    }

    private func openLink() {
        guard let url = MediaRules.videoURL(from: link) else {
            browser.notice = Notice(title: "Link non valido", message: PocketError.unsupportedLink.localizedDescription)
            return
        }
        browser.open(url)
    }
}
