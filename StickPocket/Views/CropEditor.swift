import SwiftUI

enum CropMath {
    static func selection(start: CGPoint, end: CGPoint, size: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0 else { return .zero }
        let x1 = min(1, max(0, start.x / size.width))
        let y1 = min(1, max(0, start.y / size.height))
        let x2 = min(1, max(0, end.x / size.width))
        let y2 = min(1, max(0, end.y / size.height))
        return CGRect(x: min(x1, x2), y: min(y1, y2), width: abs(x2 - x1), height: abs(y2 - y1))
    }

    static func pixels(_ normalized: CGRect, width: Int, height: Int) -> CGRect {
        CGRect(x: normalized.minX * CGFloat(width), y: normalized.minY * CGFloat(height),
               width: normalized.width * CGFloat(width), height: normalized.height * CGFloat(height))
            .integral.intersection(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    }
}

struct CropEditor: View {
    @EnvironmentObject private var store: StickerStore
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let originalName: String
    @State private var selection = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    @State private var notice: Notice?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Trascina un rettangolo attorno allo sticker.")
                    .font(.headline).multilineTextAlignment(.center).padding(.horizontal)
                GeometryReader { proxy in
                    let ratio = min(proxy.size.width / image.size.width, proxy.size.height / image.size.height)
                    let fitted = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                    ZStack(alignment: .topLeading) {
                        Image(uiImage: image).resizable().frame(width: fitted.width, height: fitted.height)
                        Rectangle().fill(.black.opacity(0.28))
                        Rectangle().stroke(Palette.lime, style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                            .background(Palette.lime.opacity(0.08))
                            .frame(width: selection.width * fitted.width, height: selection.height * fitted.height)
                            .offset(x: selection.minX * fitted.width, y: selection.minY * fitted.height)
                    }
                    .frame(width: fitted.width, height: fitted.height)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        selection = CropMath.selection(start: value.startLocation, end: value.location, size: fitted)
                    })
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .accessibilityLabel("Area di ritaglio")
                }
                HStack {
                    Button("Tutta l’immagine") { selection = CGRect(x: 0, y: 0, width: 1, height: 1) }
                    Spacer()
                    Button("Al centro") { selection = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6) }
                }.font(.subheadline).padding(.horizontal)
                Text("Salvo una nuova copia PNG. L’originale resta nella raccolta.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.padding(.vertical, 20).background(Palette.background)
                .navigationTitle("Ritaglia").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Salva") { save() }.fontWeight(.bold) }
                }
                .alert(item: $notice) { Alert(title: Text($0.title), message: Text($0.message)) }
        }
    }

    private func save() {
        do {
            let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let oriented = UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: pixelSize))
            }
            guard let cg = oriented.cgImage else { throw PocketError.invalidImage }
            let rect = CropMath.pixels(selection, width: cg.width, height: cg.height)
            guard !rect.isNull, rect.width >= 16, rect.height >= 16,
                  let cropped = cg.cropping(to: rect),
                  let bytes = UIImage(cgImage: cropped).pngData() else { throw PocketError.invalidCrop }
            _ = try store.add(data: bytes, name: originalName + " · ritaglio", origin: .crop)
            dismiss()
        } catch { notice = Notice(title: "Ritaglio non riuscito", message: error.localizedDescription) }
    }
}
