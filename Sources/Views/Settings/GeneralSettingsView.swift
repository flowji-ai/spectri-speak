import SwiftUI
import AVFoundation
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var selectedHotkey: HotkeyOption = HotkeyOption.saved
    @State private var isToggleMode: Bool = HotkeyOption.isToggleMode
    @State private var launchAtLogin: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Permissions Section
                SettingsSection(title: "Permissions") {
                    VStack(spacing: 12) {
                        PermissionSettingsRow(
                            title: "Accessibility",
                            description: "Required for global hotkey detection",
                            isGranted: appState.hasAccessibilityPermission,
                            action: requestAccessibility
                        )

                        Divider()

                        PermissionSettingsRow(
                            title: "Microphone",
                            description: "Required for voice recording",
                            isGranted: appState.hasMicrophonePermission,
                            action: requestMicrophone
                        )
                    }
                }

                // Hotkey Section
                SettingsSection(title: "Trigger Hotkey") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(hotkeyInstructionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        Picker("Hotkey", selection: $selectedHotkey) {
                            ForEach(HotkeyOption.allCases, id: \.self) { option in
                                Text(option.keyName).tag(option)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: selectedHotkey) { _, newValue in
                            HotkeyOption.saved = newValue
                            NotificationCenter.default.post(
                                name: .hotkeyChanged,
                                object: nil,
                                userInfo: ["hotkey": newValue]
                            )
                        }

                        Divider()

                        Toggle("Press twice (toggle)", isOn: $isToggleMode)
                            .onChange(of: isToggleMode) { _, newValue in
                                HotkeyOption.isToggleMode = newValue
                                NotificationCenter.default.post(
                                    name: .hotkeyToggleModeChanged,
                                    object: nil
                                )
                            }

                        Text("When enabled, press the hotkey twice quickly to start recording, and twice again to stop. When disabled, hold the key to record.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Startup Section
                SettingsSection(title: "Startup") {
                    Toggle("Launch Speak2 at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, newValue in
                            setLaunchAtLogin(newValue)
                        }
                }

                // Live Transcription Section
                SettingsSection(title: "Live Transcription") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show live transcription while recording", isOn: $appState.liveTranscriptionEnabled)

                        Text("Displays a floating overlay with real-time transcription text while you hold the hotkey.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if appState.liveTranscriptionEnabled {
                            Divider()
                                .padding(.vertical, 4)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Initial delay")
                                    Spacer()
                                    Text(String(format: "%.1fs", appState.liveTranscriptionInitialDelay))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)

                                Slider(value: $appState.liveTranscriptionInitialDelay, in: 0.2...2.0, step: 0.1)

                                Text("How long to wait before the first transcription attempt. Shorter values show text sooner but may produce less accurate initial results.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Update interval")
                                    Spacer()
                                    Text(String(format: "%.1fs", appState.liveTranscriptionTickInterval))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)

                                Slider(value: $appState.liveTranscriptionTickInterval, in: 0.3...3.0, step: 0.1)

                                Text("How often the transcription updates while recording. Shorter intervals feel more responsive but use more processing power.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if appState.currentlyLoadedModel == .parakeetV3 {
                            Label("Live transcription is only available with Whisper models.", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            checkPermissions()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private var hotkeyInstructionText: String {
        if isToggleMode {
            return "Press this key twice to start recording, press twice again to transcribe"
        } else {
            return "Hold this key to start recording, release to transcribe"
        }
    }

    private func checkPermissions() {
        appState.hasAccessibilityPermission = HotkeyManager.checkAccessibilityPermission()

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            appState.hasMicrophonePermission = true
        default:
            appState.hasMicrophonePermission = false
        }
    }

    private func requestAccessibility() {
        HotkeyManager.requestAccessibilityPermission()
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if HotkeyManager.checkAccessibilityPermission() {
                Task { @MainActor in
                    appState.hasAccessibilityPermission = true
                }
                timer.invalidate()
            }
        }
    }

    private func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Task { @MainActor in
                appState.hasMicrophonePermission = granted
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

// MARK: - Settings Section Container

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            content
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
        }
    }
}

// MARK: - Permission Row for Settings

struct PermissionSettingsRow: View {
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.subheadline)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - Notification for hotkey changes

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
    static let hotkeyToggleModeChanged = Notification.Name("hotkeyToggleModeChanged")
}
