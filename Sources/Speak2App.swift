import SwiftUI
import AppKit
import AVFoundation
import Combine

@main
struct Speak2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var setupWindowController: SetupWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var dictionaryWindowController: DictionaryWindowController?
    private var historyWindowController: TranscriptionHistoryWindowController?
    private var quickAddWindow: NSWindow?
    private var addToDictionaryWindow: NSWindow?
    private var dictationController: DictationController?
    private let appState = AppState.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasStartedDictation = false
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        // Register as service provider for right-click "Add to Dictionary"
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        // Create dictation controller early so menu can reference it
        dictationController = DictationController()

        // Setup menu bar with reference to dictation controller
        statusBarController = StatusBarController()
        statusBarController?.setup(dictationController: dictationController)

        // Listen for requests to open setup window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSetupWindow),
            name: .openSetupWindow,
            object: nil
        )

        // Listen for requests to open dictionary window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenDictionaryWindow),
            name: .openDictionaryWindow,
            object: nil
        )

        // Listen for requests to show quick add
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowQuickAdd),
            name: .showQuickAddWord,
            object: nil
        )

        // Listen for requests to open history window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenHistoryWindow),
            name: .openHistoryWindow,
            object: nil
        )

        // Listen for requests to open unified settings window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettingsWindow),
            name: .openSettingsWindow,
            object: nil
        )

        // Listen for hotkey changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotkeyChanged),
            name: .hotkeyChanged,
            object: nil
        )

        // Listen for toggle mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleModeChanged),
            name: .hotkeyToggleModeChanged,
            object: nil
        )

        // Listen for key capture mode changes (suspend/resume hotkey)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureModeChanged(_:)),
            name: .hotkeyCaptureModeChanged,
            object: nil
        )

        // Observe setup completion to start dictation
        observeSetupCompletion()

        // Check if setup is needed
        Task { @MainActor in
            await checkAndStartDictation()
        }
    }

    @objc private func handleOpenSetupWindow() {
        Task { @MainActor in
            showSetupWindow()
        }
    }

    @objc private func handleOpenDictionaryWindow() {
        Task { @MainActor in
            showDictionaryWindow()
        }
    }

    @objc private func handleShowQuickAdd() {
        Task { @MainActor in
            showQuickAddWindow()
        }
    }

    @objc private func handleOpenHistoryWindow() {
        Task { @MainActor in
            showHistoryWindow()
        }
    }

    @objc private func handleOpenSettingsWindow() {
        Task { @MainActor in
            showSettingsWindow()
        }
    }

    @objc private func handleHotkeyChanged(_ notification: Notification) {
        guard let hotkey = notification.userInfo?["hotkey"] as? HotkeyOption else { return }
        Task { @MainActor in
            dictationController?.updateHotkey(hotkey)
        }
    }

    @objc private func handleToggleModeChanged() {
        Task { @MainActor in
            dictationController?.updateToggleMode(HotkeyOption.isToggleMode)
        }
    }

    @objc private func handleCaptureModeChanged(_ notification: Notification) {
        let capturing = notification.userInfo?["capturing"] as? Bool ?? false
        Task { @MainActor in
            if capturing {
                dictationController?.suspendHotkey()
            } else {
                dictationController?.resumeHotkey()
            }
        }
    }

    @MainActor
    private func observeSetupCompletion() {
        // When setup becomes complete, start dictation if not already started
        appState.$isModelLoaded
            .combineLatest(appState.$hasAccessibilityPermission, appState.$hasMicrophonePermission)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isModelLoaded, hasAccessibility, hasMicrophone in
                guard let self = self else { return }
                if isModelLoaded && hasAccessibility && hasMicrophone && !self.hasStartedDictation {
                    Task { @MainActor in
                        await self.startDictation()
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Poll for permission changes so the app detects grants made via System Settings
    private func startPermissionPolling() {
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, !self.hasStartedDictation else {
                    // Stop polling once dictation is running
                    self?.permissionPollTimer?.invalidate()
                    self?.permissionPollTimer = nil
                    return
                }

                let hasAccessibility = HotkeyManager.checkAccessibilityPermission()
                if hasAccessibility != self.appState.hasAccessibilityPermission {
                    self.appState.hasAccessibilityPermission = hasAccessibility
                }

                let hasMic = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
                if hasMic != self.appState.hasMicrophonePermission {
                    self.appState.hasMicrophonePermission = hasMic
                }
            }
        }
    }

    @MainActor
    private func checkAndStartDictation() async {
        // Check permissions
        appState.hasAccessibilityPermission = HotkeyManager.checkAccessibilityPermission()

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            appState.hasMicrophonePermission = true
        default:
            appState.hasMicrophonePermission = false
        }

        // Show setup if needed (no model downloaded or missing permissions)
        let hasDownloadedModel = !appState.downloadedModels.isEmpty
        if !appState.hasAccessibilityPermission || !appState.hasMicrophonePermission || !hasDownloadedModel {
            showSetupWindow()
            startPermissionPolling()
            return
        }

        // Start dictation
        await startDictation()
    }

    @MainActor
    private func startDictation() async {
        guard !hasStartedDictation else { return }
        hasStartedDictation = true  // Prevent re-entrance from observer

        do {
            try await dictationController?.start()
            // Success - stop polling, dictation is running
            permissionPollTimer?.invalidate()
            permissionPollTimer = nil
        } catch {
            hasStartedDictation = false  // Allow retry on next observer fire
            appState.lastError = error.localizedDescription
            showSetupWindow()
        }
    }

    @MainActor
    private func showSetupWindow() {
        if setupWindowController == nil {
            setupWindowController = SetupWindowController()
        }
        setupWindowController?.showSetupWindow(modelManager: dictationController?.modelManager)
    }

    @MainActor
    private func showDictionaryWindow() {
        if dictionaryWindowController == nil {
            dictionaryWindowController = DictionaryWindowController()
        }
        dictionaryWindowController?.showDictionaryWindow()
    }

    @MainActor
    private func showHistoryWindow() {
        if historyWindowController == nil {
            historyWindowController = TranscriptionHistoryWindowController()
        }
        historyWindowController?.showHistoryWindow()
    }

    @MainActor
    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showSettingsWindow(modelManager: dictationController?.modelManager)
    }

    @MainActor
    private func showQuickAddWindow() {
        // Close existing quick add window if open
        quickAddWindow?.close()

        let quickAddView = QuickAddSheet()
            .environmentObject(appState.dictionaryState)
        let hostingController = NSHostingController(rootView: quickAddView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Add Word"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 300, height: 260))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        quickAddWindow = window
    }

    func applicationWillTerminate(_ notification: Notification) {
        dictationController?.stop()
    }

    // MARK: - Services Provider

    /// Handle the "Add to Speak2 Dictionary" service from right-click menu
    @objc func addToDictionary(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "No text selected" as NSString
            return
        }

        Task { @MainActor in
            showAddToDictionaryWindow(selectedText: text)
        }
    }

    @MainActor
    private func showAddToDictionaryWindow(selectedText: String) {
        // Close existing window if open
        addToDictionaryWindow?.close()

        let addView = AddToDictionarySheet(selectedText: selectedText)
            .environmentObject(appState.dictionaryState)
        let hostingController = NSHostingController(rootView: addView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Add to Dictionary"
        window.styleMask = [.titled, .closable]
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        addToDictionaryWindow = window
    }
}
