import SwiftUI
import AVFoundation
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var selectedHotkey: HotkeyOption = HotkeyOption.saved
    @State private var isToggleMode: Bool = HotkeyOption.isToggleMode
    @State private var launchAtLogin: Bool = false
    @State private var isCapturingKey = false
    @State private var capturedKeyName: String = HotkeyOption.savedCustomKeyName

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
                            if isCapturingKey {
                                isCapturingKey = false
                                NotificationCenter.default.post(name: .hotkeyCaptureModeChanged, object: nil, userInfo: ["capturing": false])
                            }
                            capturedKeyName = HotkeyOption.savedCustomKeyName
                            HotkeyOption.saved = newValue
                            NotificationCenter.default.post(
                                name: .hotkeyChanged,
                                object: nil,
                                userInfo: ["hotkey": newValue]
                            )
                        }

                        if selectedHotkey == .custom {
                            HStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isCapturingKey ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(NSColor.textBackgroundColor))
                                        )

                                    if isCapturingKey {
                                        KeyCaptureView(
                                            isCapturing: isCapturingKey,
                                            onCapture: { key in
                                                HotkeyOption.savedCustomKeycode = key.keycode
                                                HotkeyOption.savedCustomKeyIsModifier = key.isModifier
                                                HotkeyOption.savedCustomKeyName = key.displayName
                                                capturedKeyName = key.displayName
                                                isCapturingKey = false
                                                NotificationCenter.default.post(name: .hotkeyCaptureModeChanged, object: nil, userInfo: ["capturing": false])
                                                NotificationCenter.default.post(name: .hotkeyChanged, object: nil, userInfo: ["hotkey": HotkeyOption.custom])
                                            },
                                            onCancel: {
                                                isCapturingKey = false
                                                NotificationCenter.default.post(name: .hotkeyCaptureModeChanged, object: nil, userInfo: ["capturing": false])
                                            }
                                        )
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    }

                                    Text(isCapturingKey ? "Press any key (Esc to cancel)..." : (capturedKeyName.isEmpty ? "No key assigned" : capturedKeyName))
                                        .foregroundStyle(isCapturingKey ? .secondary : .primary)
                                        .font(.system(.body, design: .monospaced))
                                }
                                .frame(height: 28)
                                .onTapGesture {
                                    if !isCapturingKey {
                                        isCapturingKey = true
                                        NotificationCenter.default.post(name: .hotkeyCaptureModeChanged, object: nil, userInfo: ["capturing": true])
                                    }
                                }

                                if isCapturingKey {
                                    Button("Cancel") {
                                        isCapturingKey = false
                                        NotificationCenter.default.post(name: .hotkeyCaptureModeChanged, object: nil, userInfo: ["capturing": false])
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(.leading, 20)
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

                Spacer()
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            checkPermissions()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            capturedKeyName = HotkeyOption.savedCustomKeyName
        }
        .onDisappear {
            if isCapturingKey {
                isCapturingKey = false
                NotificationCenter.default.post(name: .hotkeyCaptureModeChanged, object: nil, userInfo: ["capturing": false])
            }
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
    static let hotkeyCaptureModeChanged = Notification.Name("hotkeyCaptureModeChanged")
}
