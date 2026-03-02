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

struct StreamingTextUpdate {
    let confirmedText: String
    let unconfirmedText: String
}

protocol StreamingTranscriptionEngine: Actor {
    func startStreaming(dictionaryHint: String?) async throws
    func stopStreaming() async throws -> String  // returns final accumulated text
    var streamingTextUpdates: AsyncStream<StreamingTextUpdate> { get }
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
