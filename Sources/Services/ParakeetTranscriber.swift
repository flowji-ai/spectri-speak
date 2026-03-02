import Foundation
import FluidAudio

actor ParakeetTranscriber: TranscriptionEngine, StreamingTranscriptionEngine {
    private var asrManager: AsrManager?
    private var loadedModels: AsrModels?
    private var isLoading = false

    // MARK: - Streaming properties
    private var streamingManager: StreamingAsrManager?
    private var _streamingTextUpdates: AsyncStream<StreamingTextUpdate>?
    private var streamContinuation: AsyncStream<StreamingTextUpdate>.Continuation?
    private var streamingUpdateTask: Task<Void, Never>?

    var isModelLoaded: Bool {
        asrManager != nil
    }

    func loadModel(progressHandler: @escaping (Double) -> Void) async throws {
        guard !isLoading && asrManager == nil else { return }
        isLoading = true

        defer { isLoading = false }

        // Download models with progress tracking
        // FluidAudio doesn't provide granular progress, so we estimate
        Task { @MainActor in
            progressHandler(0.1)
        }

        let models = try await AsrModels.downloadAndLoad(version: .v3)

        Task { @MainActor in
            progressHandler(0.8)
        }

        // Store models for reuse in streaming
        loadedModels = models

        // Initialize ASR manager
        let manager = AsrManager(config: .default)
        try await manager.initialize(models: models)

        asrManager = manager

        Task { @MainActor in
            progressHandler(1.0)
        }
    }

    func unloadModel() async {
        // Clean up any active streaming before unloading
        streamingUpdateTask?.cancel()
        streamingUpdateTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
        _streamingTextUpdates = nil
        streamingManager = nil

        asrManager = nil
        loadedModels = nil
    }

    func transcribe(audioURL: URL, dictionaryHint: String? = nil) async throws -> String {
        guard let asrManager = asrManager else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        // FluidAudio does not support vocabulary biasing
        // Dictionary processing will be handled post-transcription by DictionaryProcessor

        // FluidAudio expects 16kHz mono PCM samples
        let samples = try AudioConverter().resampleAudioFile(path: audioURL.path)
        let result = try await asrManager.transcribe(samples)

        return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        guard let models = loadedModels else {
            throw TranscriptionEngineError.modelNotLoaded
        }

        // FluidAudio does not support vocabulary biasing
        // dictionaryHint is accepted but not used; dictionary processing happens post-transcription

        let manager = StreamingAsrManager(config: .streaming)
        try await manager.start(models: models, source: .microphone)

        let (stream, continuation) = AsyncStream<StreamingTextUpdate>.makeStream()
        _streamingTextUpdates = stream
        streamContinuation = continuation
        streamingManager = manager

        // Launch a task to consume streaming transcription updates
        streamingUpdateTask = Task { [weak manager] in
            guard let manager else { return }
            let updates = await manager.transcriptionUpdates
            for await _ in updates {
                let confirmed = await manager.confirmedTranscript
                let volatile = await manager.volatileTranscript
                continuation.yield(StreamingTextUpdate(
                    confirmedText: confirmed,
                    unconfirmedText: volatile
                ))
            }
        }
    }

    func stopStreaming() async throws -> String {
        guard let manager = streamingManager else {
            return ""
        }

        let finalText = try await manager.finish()

        streamingUpdateTask?.cancel()
        streamingUpdateTask = nil
        streamContinuation?.finish()
        streamContinuation = nil
        _streamingTextUpdates = nil
        streamingManager = nil

        return finalText
    }
}
