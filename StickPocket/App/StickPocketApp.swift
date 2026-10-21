import SwiftUI

@main
struct StickPocketApp: App {
    @StateObject private var store = StickerStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .tint(Palette.lime)
                .preferredColorScheme(.dark)
        }
    }
}

enum Palette {
    static let background = Color(red: 0.055, green: 0.063, blue: 0.071)
    static let card = Color(red: 0.105, green: 0.12, blue: 0.13)
    static let lime = Color(red: 0.76, green: 1, blue: 0.46)
}

struct Notice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
