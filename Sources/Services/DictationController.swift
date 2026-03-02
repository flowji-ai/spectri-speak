import Foundation

@MainActor
class DictationController {
    private let hotkeyManager = HotkeyManager()
    private let audioRecorder = AudioRecorder()
    private let textInjector = TextInjector()
    private let dictionaryProcessor = DictionaryProcessor()
    private let appState = AppState.shared
    private let audioFeedback = AudioFeedbackManager.shared
    private var mlxRefiner: MLXRefiner?

    let modelManager = ModelManager()

    private var currentRecordingURL: URL?

    func updateHotkey(_ option: HotkeyOption) {
        hotkeyManager.updateHotkey(option)
        configureHotkeyCallbacks()
    }

    func updateToggleMode(_ isToggle: Bool) {
        hotkeyManager.updateToggleMode(isToggle)
        configureHotkeyCallbacks()
    }

    func suspendHotkey() {
        hotkeyManager.suspend()
    }

    func resumeHotkey() {
        hotkeyManager.resume()
    }

    /// Load the selected model (or specified model)
    func loadModel(_ model: TranscriptionModel? = nil) async throws {
        let targetModel = model ?? appState.selectedModel
        try await modelManager.loadModel(targetModel) { [weak self] progress in
            Task { @MainActor in
                self?.appState.modelDownloadProgress = progress
            }
        }
    }

    func start() async throws {
        // Load model if not already loaded
        if !appState.isModelLoaded {
            try await loadModel()
        }

        // Start hotkey monitoring
        guard hotkeyManager.start() else {
            throw DictationError.accessibilityDenied
        }

        configureHotkeyCallbacks()
    }

    private func configureHotkeyCallbacks() {
        if HotkeyOption.isToggleMode {
            // Toggle mode: double-tap to start/stop
            hotkeyManager.onKeyDown = nil
            hotkeyManager.onKeyUp = nil
            hotkeyManager.onToggle = { [weak self] isRecording in
                if isRecording {
                    self?.startRecordingWithFeedback()
                } else {
                    self?.stopRecordingAndTranscribeWithFeedback()
                }
            }
        } else {
            // Hold mode: hold to record, release to transcribe
            hotkeyManager.onToggle = nil
            hotkeyManager.onKeyDown = { [weak self] in
                self?.startRecording()
            }
            hotkeyManager.onKeyUp = { [weak self] in
                self?.stopRecordingAndTranscribe()
            }
        }
    }

    private func startRecordingWithFeedback() {
        audioFeedback.playRecordingStart()
        startRecording()
    }

    private func stopRecordingAndTranscribeWithFeedback() {
        audioFeedback.playRecordingStop()
        stopRecordingAndTranscribe()
    }

    private func startRecording() {
        guard appState.recordingState == .idle else { return }

        do {
            currentRecordingURL = try audioRecorder.startRecording()
            appState.recordingState = .recording
        } catch {
            appState.lastError = "Failed to start recording: \(error.localizedDescription)"
            hotkeyManager.resetToggleState()
        }
    }

    private func stopRecordingAndTranscribe() {
        guard appState.recordingState == .recording else { return }

        guard let audioURL = audioRecorder.stopRecording() else {
            appState.recordingState = .idle
            return
        }

        appState.recordingState = .transcribing

        Task {
            do {
                // Use the user's selected language for dictionary processing
                let selectedLanguage = appState.dictionaryState.selectedLanguage

                // Get dictionary hint for model prompting (mainly for WhisperKit)
                let dictionaryHint = appState.dictionaryState.promptText(for: selectedLanguage)

                // Transcribe with dictionary hint
                var text = try await modelManager.transcribe(
                    audioURL: audioURL,
                    dictionaryHint: dictionaryHint.isEmpty ? nil : dictionaryHint
                )

                // Post-process with dictionary entries (applies to all engines)
                let entries = appState.dictionaryState.enabledEntries(for: selectedLanguage)
                if !entries.isEmpty {
                    text = dictionaryProcessor.process(text, using: entries, language: selectedLanguage)
                }

                // AI refinement (if enabled)
                let refinementMode = RefinementMode.saved
                let customPrompt = UserDefaults.standard.string(forKey: "ollamaPrompt")

                switch refinementMode {
                case .builtIn:
                    await MainActor.run { appState.recordingState = .refining }
                    do {
                        if mlxRefiner == nil {
                            mlxRefiner = MLXRefiner()
                        }
                        let refiner = mlxRefiner!
                        if await !refiner.isModelLoaded {
                            try await refiner.loadModel { _ in }
                        }
                        text = try await refiner.refine(text: text, customPrompt: customPrompt)
                    } catch {
                        print("Built-in refinement skipped: \(error.localizedDescription)")
                    }

                case .external:
                    let ollamaURL = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
                    let ollamaModel = UserDefaults.standard.string(forKey: "ollamaModel") ?? "gemma3:4b"
                    if !ollamaURL.isEmpty && !ollamaModel.isEmpty {
                        await MainActor.run { appState.recordingState = .refining }
                        do {
                            text = try await OllamaRefiner.refine(
                                text: text,
                                baseURL: ollamaURL,
                                model: ollamaModel,
                                customPrompt: customPrompt
                            )
                        } catch {
                            print("Ollama refinement skipped: \(error.localizedDescription)")
                        }
                    }

                case .off:
                    break
                }

                // Add to transcription history
                let historyEntry = TranscriptionHistoryEntry(
                    text: TranscriptionHistoryStorage.truncateIfNeeded(text),
                    modelUsed: appState.currentlyLoadedModel?.displayName ?? "Unknown",
                    language: selectedLanguage,
                    audioLength: nil
                )
                await MainActor.run {
                    appState.historyState.add(historyEntry)
                }

                await MainActor.run {
                    if !text.isEmpty {
                        Task {
                            await textInjector.inject(text: text)
                        }
                    }
                    appState.recordingState = .idle
                }
            } catch {
                await MainActor.run {
                    appState.lastError = "Transcription failed: \(error.localizedDescription)"
                    appState.recordingState = .idle
                    hotkeyManager.resetToggleState()
                }
            }

            audioRecorder.cleanup()
        }
    }

    func updateRefinementMode(_ mode: RefinementMode) {
        if mode != .builtIn, let refiner = mlxRefiner {
            Task {
                await refiner.unloadModel()
            }
            mlxRefiner = nil
        }
    }

    func stop() {
        hotkeyManager.stop()
        if audioRecorder.isRecording {
            _ = audioRecorder.stopRecording()
        }
        audioRecorder.cleanup()
    }
}

enum DictationError: Error {
    case accessibilityDenied
    case microphoneDenied
    case modelNotLoaded
}
