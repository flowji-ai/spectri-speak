import SwiftUI
import AVFoundation
import ServiceManagement

struct GeneralSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var selectedHotkey: HotkeyOption = HotkeyOption.saved
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
                                Text(option.displayName).tag(option)
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
        }
    }

    private var hotkeyInstructionText: String {
        if selectedHotkey.isToggleMode {
            return "Double-tap this key to start recording, double-tap again to transcribe"
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
}
