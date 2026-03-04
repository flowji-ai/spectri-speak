import SwiftUI
import AppKit

struct CapturedCombo {
    let triggerKeycode: Int64
    let triggerIsModifier: Bool
    let requiredModifierFlags: UInt64
    let displayName: String
}

struct KeyCaptureView: NSViewRepresentable {
    var isCapturing: Bool
    var onCapture: (CapturedCombo) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        return view
    }

    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        if isCapturing {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class KeyCaptureNSView: NSView {
    var onCapture: ((CapturedCombo) -> Void)?
    var onCancel: (() -> Void)?

    /// Tracks whether a non-modifier key was pressed during this capture gesture.
    private var didPressNonModifier = false
    /// The last modifier keycode that was pressed down (for modifier-only captures).
    private var lastModifierKeycode: Int64?
    /// Currently held modifier flags.
    private var currentModifierFlags: NSEvent.ModifierFlags = []
    /// Previous flags for detecting key-down vs key-up.
    private var previousFlags: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        let keyCode = Int64(event.keyCode)
        let flags = event.modifierFlags
        let isDown = isModifierKeyDown(keyCode: keyCode, flags: flags)

        if isDown {
            lastModifierKeycode = keyCode
            currentModifierFlags = flags
        } else {
            // A modifier was released
            let allModifiersReleased = !flags.contains(.command) && !flags.contains(.option)
                && !flags.contains(.shift) && !flags.contains(.control) && !flags.contains(.function)

            if allModifiersReleased && !didPressNonModifier, let modKeycode = lastModifierKeycode {
                // All modifiers released and no regular key was pressed → modifier-only combo
                let name = KeycodeNames.name(for: modKeycode, isModifier: true)
                onCapture?(CapturedCombo(
                    triggerKeycode: modKeycode,
                    triggerIsModifier: true,
                    requiredModifierFlags: 0,
                    displayName: name
                ))
                resetState()
            }

            currentModifierFlags = flags
        }

        previousFlags = flags
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = Int64(event.keyCode)

        // Escape cancels capture
        if keyCode == 0x35 {
            onCancel?()
            resetState()
            return
        }

        didPressNonModifier = true

        let modFlags = extractCGEventModifierFlags(from: event.modifierFlags)
        let displayName = buildDisplayName(modifierFlags: event.modifierFlags, triggerKeycode: keyCode)

        onCapture?(CapturedCombo(
            triggerKeycode: keyCode,
            triggerIsModifier: false,
            requiredModifierFlags: modFlags,
            displayName: displayName
        ))
        resetState()
    }

    override func keyUp(with event: NSEvent) {
        // Swallow key-up events during capture to prevent system beep
    }

    private func resetState() {
        didPressNonModifier = false
        lastModifierKeycode = nil
        currentModifierFlags = []
        previousFlags = []
    }

    private func isModifierKeyDown(keyCode: Int64, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 0x3A, 0x3D: // Left/Right Option
            return flags.contains(.option) && !previousFlags.contains(.option)
        case 0x37, 0x36: // Left/Right Command
            return flags.contains(.command) && !previousFlags.contains(.command)
        case 0x38, 0x3C: // Left/Right Shift
            return flags.contains(.shift) && !previousFlags.contains(.shift)
        case 0x3B, 0x3E: // Left/Right Control
            return flags.contains(.control) && !previousFlags.contains(.control)
        case 0x3F: // Fn
            return flags.contains(.function) && !previousFlags.contains(.function)
        default:
            return false
        }
    }
}

// MARK: - Display name building

/// Build a display name in standard macOS order: Ctrl + Option + Shift + Cmd + Key
func buildDisplayName(modifierFlags: NSEvent.ModifierFlags, triggerKeycode: Int64) -> String {
    var parts: [String] = []
    if modifierFlags.contains(.control) { parts.append("Ctrl") }
    if modifierFlags.contains(.option)  { parts.append("Option") }
    if modifierFlags.contains(.shift)   { parts.append("Shift") }
    if modifierFlags.contains(.command) { parts.append("Cmd") }
    parts.append(KeycodeNames.name(for: triggerKeycode, isModifier: false))
    return parts.joined(separator: " + ")
}

/// Extract CGEventFlags bitmask from NSEvent.ModifierFlags (only modifier bits).
func extractCGEventModifierFlags(from flags: NSEvent.ModifierFlags) -> UInt64 {
    var result: UInt64 = 0
    if flags.contains(.control) { result |= CGEventFlags.maskControl.rawValue }
    if flags.contains(.option)  { result |= CGEventFlags.maskAlternate.rawValue }
    if flags.contains(.shift)   { result |= CGEventFlags.maskShift.rawValue }
    if flags.contains(.command) { result |= CGEventFlags.maskCommand.rawValue }
    return result
}

// MARK: - Keycode Names

enum KeycodeNames {
    private static let modifierNames: [Int64: String] = [
        0x37: "Left Command",  0x36: "Right Command",
        0x3A: "Left Option",   0x3D: "Right Option",
        0x38: "Left Shift",    0x3C: "Right Shift",
        0x3B: "Left Control",  0x3E: "Right Control",
        0x3F: "Fn",
    ]

    private static let keyNames: [Int64: String] = [
        // Special keys
        0x31: "Space",    0x24: "Return",        0x30: "Tab",
        0x33: "Delete",   0x75: "Forward Delete",
        // F-keys
        0x7A: "F1",  0x78: "F2",  0x63: "F3",  0x76: "F4",
        0x60: "F5",  0x61: "F6",  0x62: "F7",  0x64: "F8",
        0x65: "F9",  0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x69: "F13", 0x6B: "F14", 0x71: "F15",
        // Navigation
        0x7E: "Up Arrow",   0x7D: "Down Arrow",
        0x7B: "Left Arrow", 0x7C: "Right Arrow",
        0x73: "Home",       0x77: "End",
        0x74: "Page Up",    0x79: "Page Down",
        // Letters
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E",
        0x03: "F", 0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J",
        0x28: "K", 0x25: "L", 0x2E: "M", 0x2D: "N", 0x1F: "O",
        0x23: "P", 0x0C: "Q", 0x0F: "R", 0x01: "S", 0x11: "T",
        0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X", 0x10: "Y",
        0x06: "Z",
        // Numbers
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5",
        0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        // Symbols
        0x1B: "-", 0x18: "=", 0x21: "[", 0x1E: "]", 0x2A: "\\",
        0x29: ";", 0x27: "'", 0x2B: ",", 0x2F: ".", 0x2C: "/",
        0x32: "`",
    ]

    static func name(for keycode: Int64, isModifier: Bool) -> String {
        if isModifier {
            return modifierNames[keycode] ?? "Modifier \(keycode)"
        }
        return keyNames[keycode] ?? "Key \(keycode)"
    }
}
