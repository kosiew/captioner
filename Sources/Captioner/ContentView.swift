import AppKit
import SwiftUI
import UniformTypeIdentifiers

// ObservableObject rather than @Observable/@State: the SwiftUI macro plugins
// ship only with Xcode, and this builds with the Command Line Tools alone.
@MainActor
final class CaptionViewModel: ObservableObject {
    @Published var image: NSImage?
    @Published var style: CaptionStyle = .funny
    @Published var language: CaptionLanguage =
        CaptionLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .english {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: "language") }
    }
    @Published var captions: [String] = []
    @Published var isGenerating = false
    @Published var errorMessage: String?
    @Published var isDropTargeted = false
    @Published var copiedCaption: String?

    private let generator = CaptionGenerator()
    private var task: Task<Void, Never>?

    var availabilityWarning: String? { generator.unavailableReason }

    func setImage(_ newImage: NSImage) {
        image = newImage
        captions = []
        errorMessage = nil
        generate()
    }

    func pasteFromClipboard() {
        let pasteboard = NSPasteboard.general
        if let url = (pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL])?.first,
           let image = NSImage(contentsOf: url) {
            setImage(image)
        } else if let image = NSImage(pasteboard: pasteboard) {
            setImage(image)
        } else {
            errorMessage = "The clipboard doesn't contain an image."
        }
    }

    /// Rotates the image 90° clockwise and refreshes the captions. Generation is
    /// briefly delayed so that several quick rotations only trigger one request.
    func rotateClockwise() {
        guard let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let rotated = cgImage.rotatedClockwise() else { return }
        image = NSImage(cgImage: rotated, size: .zero)
        captions = []
        generate(after: .milliseconds(700))
    }

    func copy(_ caption: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(caption, forType: .string)
        copiedCaption = caption
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedCaption == caption { copiedCaption = nil }
        }
    }

    func generate() { generate(after: .zero) }

    private func generate(after delay: Duration) {
        guard let cgImage = image?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        task?.cancel()
        isGenerating = true
        errorMessage = nil
        let style = style
        let language = language
        task = Task {
            // A cancelled task must not clear the spinner of the task that replaced it.
            defer { if !Task.isCancelled { isGenerating = false } }
            do {
                try await Task.sleep(for: delay)
                let result = try await generator.captions(for: cgImage, style: style, language: language)
                guard !Task.isCancelled else { return }
                captions = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
        }
    }
}

extension CGImage {
    func rotatedClockwise() -> CGImage? {
        guard let context = CGContext(data: nil, width: height, height: width, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(width))
        context.rotate(by: -.pi / 2)
        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}

struct ContentView: View {
    @StateObject private var model = CaptionViewModel()

    var body: some View {
        VStack(spacing: 16) {
            if let warning = model.availabilityWarning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            dropZone

            HStack {
                Picker("Style", selection: $model.style) {
                    ForEach(CaptionStyle.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()

                Picker("Language", selection: $model.language) {
                    ForEach(CaptionLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
                .help("Caption language")

                Spacer()

                Button("Rotate", systemImage: "rotate.right", action: model.rotateClockwise)
                    .help("Rotate 90° clockwise (⌘R)")
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.image == nil)

                Button("Paste", systemImage: "doc.on.clipboard", action: model.pasteFromClipboard)
                    .keyboardShortcut("v", modifiers: .command)

                Button(model.captions.isEmpty ? "Suggest" : "Regenerate",
                       systemImage: "apple.intelligence", action: model.generate)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.image == nil || model.isGenerating)
            }
            .onChange(of: model.style) { if model.image != nil { model.generate() } }
            .onChange(of: model.language) { if model.image != nil { model.generate() } }

            captionList
        }
        .padding(20)
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(model.isDropTargeted ? Color.accentColor : .secondary.opacity(0.4),
                              style: StrokeStyle(lineWidth: 2, dash: model.image == nil ? [8] : []))
                .background(RoundedRectangle(cornerRadius: 14).fill(.quaternary.opacity(model.isDropTargeted ? 0.6 : 0.25)))

            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                    Text("Drop an image here")
                        .font(.headline)
                    Text("or press ⌘V to paste from the clipboard")
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 260)
        .onDrop(of: [.fileURL, .image], isTargeted: $model.isDropTargeted, perform: handleDrop)
    }

    @ViewBuilder
    private var captionList: some View {
        if model.isGenerating {
            ProgressView("Thinking up captions…")
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if let error = model.errorMessage {
            Label(error, systemImage: "xmark.octagon")
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if !model.captions.isEmpty {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(model.captions, id: \.self) { caption in
                        CaptionRow(text: caption, copied: model.copiedCaption == caption) { model.copy(caption) }
                    }
                }
            }
            .frame(minHeight: 120)
        } else {
            Spacer(minLength: 120)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, let image = NSImage(contentsOf: url) else { return }
                Task { @MainActor in model.setImage(image) }
            }
            return true
        }
        if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                guard let image = image as? NSImage else { return }
                Task { @MainActor in model.setImage(image) }
            }
            return true
        }
        return false
    }
}

struct CaptionRow: View {
    let text: String
    let copied: Bool
    let onCopy: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Text(text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc", action: onCopy)
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(.background.secondary))
    }
}
