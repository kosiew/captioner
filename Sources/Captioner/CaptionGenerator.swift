import CoreGraphics
import FoundationModels
import Vision

enum CaptionStyle: String, CaseIterable, Identifiable {
    case funny = "Funny"
    case thoughtful = "Thoughtful"
    case poetic = "Poetic"
    case minimal = "Minimal"
    case wholesome = "Wholesome"
    case romantic = "Romantic"
    case nostalgic = "Nostalgic"
    case movieTrailer = "Movie Trailer"
    case songLyric = "Song Lyric Vibes"
    case pun = "Pun"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .funny: "face.smiling"
        case .thoughtful: "lightbulb"
        case .poetic: "text.quote"
        case .minimal: "minus"
        case .wholesome: "sun.max"
        case .romantic: "heart"
        case .nostalgic: "clock.arrow.circlepath"
        case .movieTrailer: "film"
        case .songLyric: "music.note"
        case .pun: "textformat.abc"
        }
    }

    var guidance: String {
        switch self {
        case .funny:
            "Write witty, playful, light-hearted captions. Puns, gentle irony and observational humor are welcome. Keep it kind."
        case .thoughtful:
            "Write reflective, warm, meaningful captions that evoke a feeling or a small insight about the moment. Avoid clichés."
        case .poetic:
            "Write lyrical captions rich in imagery, metaphor and rhythm. A caption may be a tiny poem or haiku, with lines separated by ' / '."
        case .minimal:
            "Write ultra-short captions of two to five words. Understated and cool. No emojis, little or no punctuation."
        case .wholesome:
            "Write sweet, heartwarming, feel-good captions full of gratitude and gentle joy. Perfect for family, friends and pets."
        case .romantic:
            "Write tender, affectionate captions about love, closeness and shared moments. Heartfelt rather than cheesy."
        case .nostalgic:
            "Write wistful, bittersweet captions that look back fondly, as if remembering this moment years later."
        case .movieTrailer:
            "Write captions as dramatic movie-trailer narration, e.g. 'In a world where...'. Epic, over-the-top and suspenseful about something ordinary."
        case .songLyric:
            "Write captions that sound like an original catchy song lyric or chorus line, with rhythm and rhyme. Never quote or paraphrase real songs."
        case .pun:
            "Write captions that each hinge on one clever pun or play on words tied to what is in the image."
        }
    }
}

enum CaptionLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"

    var id: Self { self }

    /// Menu label, shown in the language itself.
    var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        }
    }

    var guidance: String {
        switch self {
        case .english:
            "Write every caption in English."
        case .simplifiedChinese:
            "Write every caption in Simplified Chinese (简体中文) only, using simplified characters. Use natural, idiomatic Chinese (wordplay, 谐音 and 成语 are welcome) rather than translating from English. Treat any word-count limits as a similarly short number of characters."
        case .traditionalChinese:
            "Write every caption in Traditional Chinese (繁體中文) only, using traditional characters. Use natural, idiomatic Chinese (wordplay, 諧音 and 成語 are welcome) rather than translating from English. Treat any word-count limits as a similarly short number of characters."
        }
    }
}

/// `{ captions: [String] }` with exactly 5 items. Built dynamically so the app
/// compiles without the `@Generable` macro plugin (which ships only with Xcode).
private let captionSchema: GenerationSchema = {
    let root = DynamicGenerationSchema(
        name: "CaptionSet",
        properties: [
            .init(name: "captions",
                  description: "Distinct caption suggestions, each a short caption suitable for social media",
                  schema: .init(arrayOf: .init(type: String.self), minimumElements: 5, maximumElements: 5))
        ]
    )
    return try! GenerationSchema(root: root, dependencies: [])
}()

enum CaptionError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): reason
        }
    }
}

struct CaptionGenerator {
    private let model = SystemLanguageModel.default

    /// Human-readable reason Apple Intelligence can't be used, or nil when ready.
    var unavailableReason: String? {
        switch model.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            "This Mac doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            "Turn on Apple Intelligence in System Settings to generate captions."
        case .unavailable(.modelNotReady):
            "The Apple Intelligence model is still downloading. Try again shortly."
        case .unavailable:
            "Apple Intelligence is unavailable."
        }
    }

    func captions(for image: CGImage, style: CaptionStyle, language: CaptionLanguage) async throws -> [String] {
        if let reason = unavailableReason { throw CaptionError.unavailable(reason) }

        let session = LanguageModelSession(model: model, instructions: """
            You are a creative social-media caption writer.
            \(style.guidance)
            Never use hashtags. Never describe the image literally like 'This image shows'. Each caption must be different in angle.
            \(language.guidance)
            """)
        let options = GenerationOptions(temperature: 0.9)

        let response: LanguageModelSession.Response<GeneratedContent>
        if model.capabilities.contains(.vision) {
            response = try await session.respond(schema: captionSchema, options: options) {
                "Suggest \(style.rawValue.lowercased()) captions for this image."
                Attachment(image)
            }
        } else {
            // Older on-device model without image input: describe the image with Vision first.
            let description = try await ImageDescriber.describe(image)
            response = try await session.respond(schema: captionSchema, options: options) {
                "Suggest \(style.rawValue.lowercased()) captions for a photo with these details:"
                description
            }
        }
        return try response.content.value([String].self, forProperty: "captions")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\""))) }
            .filter { !$0.isEmpty }
    }
}

/// Builds a short text description of an image using the Vision framework.
enum ImageDescriber {
    static func describe(_ image: CGImage) async throws -> String {
        async let labels = ClassifyImageRequest().perform(on: image)
        async let text = RecognizeTextRequest().perform(on: image)
        async let faces = DetectFaceRectanglesRequest().perform(on: image)

        let topLabels = try await labels
            .filter { $0.confidence > 0.3 }
            .prefix(8)
            .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        let lines = try await text.compactMap { $0.topCandidates(1).first?.string }.prefix(5)
        let faceCount = try await faces.count

        var parts: [String] = []
        if !topLabels.isEmpty { parts.append("Contents: \(topLabels.joined(separator: ", ")).") }
        if faceCount > 0 { parts.append("People visible: \(faceCount).") }
        if !lines.isEmpty { parts.append("Visible text: \(lines.joined(separator: " / ")).") }
        return parts.isEmpty ? "An everyday photo." : parts.joined(separator: " ")
    }
}
