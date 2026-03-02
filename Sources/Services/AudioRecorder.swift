import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?

    var isRecording: Bool {
        audioEngine?.isRunning ?? false
    }

    func startRecording() throws -> URL {
        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "speak2_recording_\(Date().timeIntervalSince1970).wav"
        let fileURL = tempDir.appendingPathComponent(fileName)
        self.tempFileURL = fileURL

        // Convert to 16kHz mono for Whisper
        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            throw AudioRecorderError.converterError
        }

        let audioFile = try AVAudioFile(
            forWriting: fileURL,
            settings: whisperFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        self.audioFile = audioFile

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, converter: converter, outputFormat: whisperFormat)
        }

        audioEngine.prepare()
        try audioEngine.start()

        return fileURL
    }

    private func processBuffer(_ buffer: AVAudioPCMBuffer, converter: AVAudioConverter, outputFormat: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(outputFormat.sampleRate * Double(buffer.frameLength) / buffer.format.sampleRate)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else { return }

        do {
            try audioFile?.write(from: outputBuffer)
        } catch {
            print("Error writing audio buffer: \(error)")
        }
    }

    func stopRecording() -> URL? {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        audioFile = nil

        return tempFileURL
    }

    func cleanup() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }
}

enum AudioRecorderError: Error {
    case formatError
    case converterError
}
