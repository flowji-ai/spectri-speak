import Accelerate
import AVFoundation
import Foundation
import FluidAudio

private func parakeetLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[ParakeetStream] \(message())")
    #endif
}

actor ParakeetTranscriber: TranscriptionEngine, StreamingTranscriptionEngine {
    /// Minimum audio samples before attempting transcription (0.3s at 16kHz)
    private let minTranscriptionSamples = 4800
    /// Maximum samples to send per streaming pass (5s at 16kHz)
    private let maxStreamingSamples = 80000

    private var asrManager: AsrManager?
    private var loadedModels: AsrModels?
    private var isLoading = false

    // MARK: - Streaming properties
    private var audioEngine: AVAudioEngine?
    private var audioBuffer: AudioSampleBuffer?
    private var streamingTask: Task<Void, Error>?
    private var _streamingTextUpdates: AsyncStream<StreamingTextUpdate>?
    private var streamContinuation: AsyncStream<StreamingTextUpdate>.Continuation?
    private let latestStreamingText = StreamingTextSnapshot()

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
        // Clean up audio engine if running
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        audioBuffer = nil

        streamingTask?.cancel()
        let pendingTask = streamingTask
        streamingTask = nil
        _ = try? await pendingTask?.value
        streamContinuation?.finish()
        streamContinuation = nil
        _streamingTextUpdates = nil

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
        guard let asrManager = asrManager else {
            parakeetLog("startStreaming: model not loaded, throwing")
            throw TranscriptionEngineError.modelNotLoaded
        }

        parakeetLog("startStreaming called")
        latestStreamingText.reset()

        // Create AsyncStream + continuation
        let (stream, continuation) = AsyncStream<StreamingTextUpdate>.makeStream()
        _streamingTextUpdates = stream
        streamContinuation = continuation

        // Set up AudioSampleBuffer
        let buffer = AudioSampleBuffer()
        audioBuffer = buffer

        // Set up AVAudioEngine
        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw TranscriptionEngineError.transcriptionFailed("Failed to create 16kHz mono format")
        }

        guard let converter = AVAudioConverter(from: hardwareFormat, to: targetFormat) else {
            throw TranscriptionEngineError.transcriptionFailed("Failed to create audio converter")
        }

        parakeetLog("Hardware format: \(hardwareFormat)")

        // Sample counter for periodic RMS/peak logging (~1 second intervals)
        var samplesSinceLastLog: Int = 0

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: hardwareFormat) { tapBuffer, _ in
            let frameCount = AVAudioFrameCount(
                targetFormat.sampleRate * Double(tapBuffer.frameLength) / tapBuffer.format.sampleRate
            )
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return tapBuffer
            }

            guard status != .error, error == nil else { return }

            guard let channelData = outputBuffer.floatChannelData else { return }
            let length = Int(outputBuffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: length))

            buffer.append(samples)

            // Log RMS/peak every ~1 second
            samplesSinceLastLog += length
            if samplesSinceLastLog >= 16000 {
                samples.withUnsafeBufferPointer { ptr in
                    var rms: Float = 0
                    var peak: Float = 0
                    vDSP_rmsqv(ptr.baseAddress!, 1, &rms, vDSP_Length(ptr.count))
                    vDSP_maxmgv(ptr.baseAddress!, 1, &peak, vDSP_Length(ptr.count))
                    parakeetLog("Audio level — RMS: \(rms), Peak: \(peak), Total samples: \(buffer.count)")
                }
                samplesSinceLastLog = 0
            }
        }

        engine.prepare()

        do {
            try engine.start()
            parakeetLog("Audio engine started")
        } catch {
            parakeetLog("Error starting audio engine: \(error)")
            continuation.finish()
            streamContinuation = nil
            _streamingTextUpdates = nil
            audioEngine = nil
            audioBuffer = nil
            throw TranscriptionEngineError.transcriptionFailed("Audio engine failed to start: \(error.localizedDescription)")
        }

        // Launch streaming transcription loop
        let snapshot = latestStreamingText
        let capturedAsrManager = asrManager
        let capturedMinSamples = minTranscriptionSamples
        let capturedMaxSamples = maxStreamingSamples

        streamingTask = Task {
            var previousText = ""

            while !Task.isCancelled {
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms

                let allSamples = buffer.snapshot()

                guard allSamples.count >= capturedMinSamples else { continue }

                // Cap at ~5 seconds to keep each pass fast
                let samples = allSamples.count > capturedMaxSamples
                    ? Array(allSamples.suffix(capturedMaxSamples))
                    : allSamples

                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    let result = try await capturedAsrManager.transcribe(samples)
                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

                    let currentText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)

                    parakeetLog("pass: \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000.0))s audio) → \(String(format: "%.1f", elapsed))s → '\(currentText)'")

                    // Skip empty results to avoid flickering the overlay
                    guard !currentText.isEmpty else { continue }

                    let diff = diffWords(previous: previousText, current: currentText)
                    previousText = currentText

                    snapshot.update(confirmed: diff.confirmed, unconfirmed: diff.unconfirmed)
                    continuation.yield(StreamingTextUpdate(
                        confirmedText: diff.confirmed,
                        unconfirmedText: diff.unconfirmed
                    ))
                } catch {
                    parakeetLog("Transcription error: \(error)")
                }
            }
        }
    }

    // MARK: - Stop Streaming

    /// Write Float32 samples to a temporary 16kHz mono WAV file for reliable transcription.
    private func writeSamplesToTempFile(_ samples: [Float]) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("parakeet_stream_\(UUID().uuidString).wav")

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw TranscriptionEngineError.transcriptionFailed("Failed to create audio format")
        }

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw TranscriptionEngineError.transcriptionFailed("Failed to create PCM buffer")
        }

        pcmBuffer.frameLength = AVAudioFrameCount(samples.count)
        memcpy(pcmBuffer.floatChannelData![0], samples, samples.count * MemoryLayout<Float>.size)

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: format.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try audioFile.write(from: pcmBuffer)

        return fileURL
    }

    func stopStreaming() async throws -> String {
        parakeetLog("stopStreaming called")

        // 1. Stop audio engine
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil

        // 2. Cancel streaming loop and await completion to avoid racing
        streamingTask?.cancel()
        let task = streamingTask
        streamingTask = nil
        try? await task?.value

        // 3. Final transcription — write buffer to temp file for reliable results
        var finalText = ""

        if let buffer = audioBuffer, let asrManager = asrManager {
            let samples = buffer.snapshot()
            parakeetLog("stopStreaming: buffer has \(samples.count) samples (\(String(format: "%.1f", Double(samples.count) / 16000.0))s)")
            if samples.count >= minTranscriptionSamples {
                do {
                    let tempFile = try writeSamplesToTempFile(samples)
                    defer { try? FileManager.default.removeItem(at: tempFile) }

                    let result = try await asrManager.transcribe(tempFile)
                    finalText = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    parakeetLog("stopStreaming: final transcription = '\(finalText)'")
                } catch {
                    parakeetLog("Final transcription error: \(error)")
                }
            }
        } else {
            parakeetLog("stopStreaming: buffer or asrManager is nil")
        }

        // 4. Fallback: if final transcription failed or empty, use latest snapshot
        if finalText.isEmpty {
            let (confirmed, unconfirmed) = latestStreamingText.read()
            parakeetLog("stopStreaming: final empty, falling back to snapshot: confirmed='\(confirmed)' unconfirmed='\(unconfirmed)'")
            finalText = [confirmed, unconfirmed]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        parakeetLog("stopStreaming: returning '\(finalText)'")

        // 5. Clean up all state
        streamContinuation?.finish()
        streamContinuation = nil
        _streamingTextUpdates = nil
        audioBuffer?.reset()
        audioBuffer = nil

        return finalText
    }
}
