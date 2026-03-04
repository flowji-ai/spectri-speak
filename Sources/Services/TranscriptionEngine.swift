import Foundation

/// Protocol defining a speech-to-text transcription engine.
/// Implementations must be actors to ensure thread-safe model access.
protocol TranscriptionEngine: Actor {
    /// Whether the model is currently loaded and ready for transcription
    var isModelLoaded: Bool { get }

    /// Load the model, reporting progress via the handler
    /// - Parameter progressHandler: Called with progress from 0.0 to 1.0
    func loadModel(progressHandler: @escaping (Double) -> Void) async throws

    /// Unload the model to free memory
    func unloadModel() async

    /// Transcribe audio from the given file URL
    /// - Parameters:
    ///   - audioURL: Path to 16kHz mono PCM audio file
    ///   - dictionaryHint: Optional comma-separated list of words to prioritize during transcription
    /// - Returns: Transcribed text
    func transcribe(audioURL: URL, dictionaryHint: String?) async throws -> String
}

struct StreamingTextUpdate: Sendable {
    let confirmedText: String
    let unconfirmedText: String
}

protocol StreamingTranscriptionEngine: Actor {
    func startStreaming(dictionaryHint: String?) async throws
    func stopStreaming() async throws -> String  // returns final accumulated text
    var streamingTextUpdates: AsyncStream<StreamingTextUpdate> { get }
}

// MARK: - Word-level diff helper (shared by Whisper and Parakeet streaming)

/// Word-level common-prefix diff. Words stable across consecutive transcription passes = confirmed.
/// Remainder = unconfirmed. Case-insensitive, punctuation-tolerant comparison.
func diffWords(previous: String, current: String) -> (confirmed: String, unconfirmed: String) {
    let previousWords = previous.split(separator: " ").map(String.init)
    let currentWords = current.split(separator: " ").map(String.init)

    var commonCount = 0
    let minCount = min(previousWords.count, currentWords.count)
    for i in 0..<minCount {
        if normalizeForComparison(previousWords[i]) == normalizeForComparison(currentWords[i]) {
            commonCount += 1
        } else {
            break
        }
    }

    let confirmed = currentWords.prefix(commonCount).joined(separator: " ")
    let unconfirmed = currentWords.dropFirst(commonCount).joined(separator: " ")

    return (confirmed: confirmed, unconfirmed: unconfirmed)
}

func normalizeForComparison(_ word: String) -> String {
    var s = word.lowercased()
    while let last = s.last, last.isPunctuation {
        s.removeLast()
    }
    return s
}

// MARK: - Transcription artifact stripping

/// Strip bracketed artifacts that Whisper sometimes produces (e.g., [Silence], [BLANK_AUDIO], (Music)).
func stripTranscriptionArtifacts(_ text: String) -> String {
    text.replacingOccurrences(of: "\\[.*?\\]|\\(.*?\\)", with: "", options: .regularExpression)
        .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

enum TranscriptionEngineError: Error, LocalizedError {
    case modelNotLoaded
    case transcriptionFailed(String)
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Model is not loaded"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}
