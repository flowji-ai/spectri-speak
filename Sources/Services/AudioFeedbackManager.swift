import AppKit
import AVFoundation

/// Provides audio feedback for toggle-mode dictation using macOS dictation sounds.
class AudioFeedbackManager {
    static let shared = AudioFeedbackManager()

    private var audioPlayer: AVAudioPlayer?

    // macOS system dictation sounds
    private let beginRecordPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/begin_record.caf"
    private let endRecordPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/end_record.caf"

    private init() {}

    /// Play feedback sound when recording starts (macOS dictation begin sound).
    func playRecordingStart() {
        playSound(at: beginRecordPath)
    }

    /// Play feedback sound when recording stops (macOS dictation end sound).
    func playRecordingStop() {
        playSound(at: endRecordPath)
    }

    private func playSound(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            // Fallback to system sounds if dictation sounds not available
            NSSound(named: "Tink")?.play()
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            // Fallback to system sound
            NSSound(named: "Tink")?.play()
        }
    }
}
