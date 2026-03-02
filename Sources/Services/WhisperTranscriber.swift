import Foundation
import os
import WhisperKit

/// Thread-safe container for the latest streaming text, written from the AudioStreamTranscriber callback
/// and read from the WhisperTranscriber actor when stopping.
private final class StreamingTextSnapshot: @unchecked Sendable {
    private var lock = os_unfair_lock()
    private var _confirmed: String = ""
    private var _unconfirmed: String = ""

    func update(confirmed: String, unconfirmed: String) {
        os_unfair_lock_lock(&lock)
        _confirmed = confirmed
        _unconfirmed = unconfirmed
        os_unfair_lock_unlock(&lock)
    }

    func read() -> (confirmed: String, unconfirmed: String) {
        os_unfair_lock_lock(&lock)
        let result = (_confirmed, _unconfirmed)
        os_unfair_lock_unlock(&lock)
        return result
    }
}

actor WhisperTranscriber: TranscriptionEngine, StreamingTranscriptionEngine {
    private var whisperKit: WhisperKit?
    private var isLoading = false

    // MARK: - Streaming properties
    private var streamTranscriber: AudioStreamTranscriber?
    private var _streamingTextUpdates: AsyncStream<StreamingTextUpdate>?
    private var streamContinuation: AsyncStream<StreamingTextUpdate>.Continuation?
    private let latestStreamingText = StreamingTextSnapshot()

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

    // MARK: - StreamingTranscriptionEngine

    var streamingTextUpdates: AsyncStream<StreamingTextUpdate> {
        if let stream = _streamingTextUpdates {
            return stream
        }
        // Return an empty finished stream if not streaming
        return AsyncStream { $0.finish() }
    }

    func startStreaming(dictionaryHint: String?) async throws {
        guard let whisperKit = whisperKit else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        guard let tokenizer = whisperKit.tokenizer else {
            throw TranscriptionEngineError.transcriptionFailed("Tokenizer not available")
        }

        var decodeOptions = DecodingOptions()
        if let hint = dictionaryHint, !hint.isEmpty {
            decodeOptions.promptTokens = tokenizer.encode(text: hint)
        }

        let (stream, continuation) = AsyncStream<StreamingTextUpdate>.makeStream()
        _streamingTextUpdates = stream
        streamContinuation = continuation
        let snapshot = latestStreamingText

        let transcriber = AudioStreamTranscriber(
            audioEncoder: whisperKit.audioEncoder,
            featureExtractor: whisperKit.featureExtractor,
            segmentSeeker: whisperKit.segmentSeeker,
            textDecoder: whisperKit.textDecoder,
            tokenizer: tokenizer,
            audioProcessor: whisperKit.audioProcessor,
            decodingOptions: decodeOptions,
            stateChangeCallback: { oldState, newState in
                let confirmed = newState.confirmedSegments
                    .map(\.text)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let unconfirmed = newState.unconfirmedSegments
                    .map(\.text)
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                snapshot.update(confirmed: confirmed, unconfirmed: unconfirmed)
                continuation.yield(StreamingTextUpdate(
                    confirmedText: confirmed,
                    unconfirmedText: unconfirmed
                ))
            }
        )
        streamTranscriber = transcriber

        try await transcriber.startStreamTranscription()
    }

    func stopStreaming() async throws -> String {
        guard let transcriber = streamTranscriber else {
            return ""
        }

        // stopStreamTranscription triggers a final state change (isRecording = false),
        // which fires the callback and updates latestStreamingText
        await transcriber.stopStreamTranscription()

        let (confirmed, unconfirmed) = latestStreamingText.read()
        let finalText = [confirmed, unconfirmed]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        streamContinuation?.finish()
        streamContinuation = nil
        _streamingTextUpdates = nil
        streamTranscriber = nil

        return finalText
    }
}
