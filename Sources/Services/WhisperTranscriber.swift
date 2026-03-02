import Foundation
import WhisperKit

actor WhisperTranscriber: TranscriptionEngine {
    private var whisperKit: WhisperKit?
    private var isLoading = false

    var isModelLoaded: Bool {
        whisperKit != nil
    }

    /// Load a Whisper model by variant string (e.g. "base.en", "small.en", "large-v3").
    /// Returns the model folder URL so the caller can persist it for isDownloaded/delete.
    func loadModel(variant: String, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        guard !isLoading && whisperKit == nil else {
            throw TranscriptionEngineError.modelNotLoaded
        }
        isLoading = true

        defer { isLoading = false }

        // Download model first with progress tracking
        let modelFolder = try await WhisperKit.download(
            variant: variant,
            downloadBase: await AppState.modelStorageLocation,
            progressCallback: { progress in
                Task { @MainActor in
                    progressHandler(progress.fractionCompleted)
                }
            }
        )

        // Initialize WhisperKit with the downloaded model (no re-download needed)
        let config = WhisperKitConfig(
            modelFolder: modelFolder.path,
            verbose: false,
            logLevel: .none,
            prewarm: true,
            load: true,
            download: false
        )

        whisperKit = try await WhisperKit(config)
        return modelFolder
    }

    // MARK: - TranscriptionEngine (protocol)

    /// Protocol conformance; uses default variant. Prefer loadModel(variant:progressHandler:) for multi-variant use.
    func loadModel(progressHandler: @escaping (Double) -> Void) async throws {
        _ = try await loadModel(variant: "base.en", progressHandler: progressHandler)
    }

    func unloadModel() async {
        whisperKit = nil
    }

    func transcribe(audioURL: URL, dictionaryHint: String? = nil) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        var results: [TranscriptionResult]

        // Try with vocabulary hint first if provided
        if let hint = dictionaryHint, !hint.isEmpty {
            var decodeOptions = DecodingOptions()
            decodeOptions.promptTokens = whisperKit.tokenizer?.encode(text: hint)

            results = try await whisperKit.transcribe(
                audioPath: audioURL.path,
                decodeOptions: decodeOptions
            )

            // Fallback: if promptTokens caused empty results, retry without
            if results.isEmpty || results.allSatisfy({ $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
                results = try await whisperKit.transcribe(audioPath: audioURL.path)
            }
        } else {
            results = try await whisperKit.transcribe(audioPath: audioURL.path)
        }

        let transcription = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return transcription
    }

    // MARK: - Live transcription (not part of TranscriptionEngine protocol)

    /// Transcribe from an in-memory audio sample array (16kHz mono float32).
    func transcribe(audioSamples: [Float], dictionaryHint: String? = nil) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        // Minimum ~0.3s of audio at 16kHz
        guard audioSamples.count >= 4800 else {
            return ""
        }

        var results: [TranscriptionResult]

        if let hint = dictionaryHint, !hint.isEmpty {
            var decodeOptions = DecodingOptions()
            decodeOptions.promptTokens = whisperKit.tokenizer?.encode(text: hint)

            results = try await whisperKit.transcribe(
                audioArray: audioSamples,
                decodeOptions: decodeOptions
            )

            if results.isEmpty || results.allSatisfy({ $0.text.trimmingCharacters(in: .whitespaces).isEmpty }) {
                results = try await whisperKit.transcribe(audioArray: audioSamples)
            }
        } else {
            results = try await whisperKit.transcribe(audioArray: audioSamples)
        }

        return results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
