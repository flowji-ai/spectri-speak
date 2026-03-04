import SwiftUI
import AppKit

struct CapturedKey {
    let keycode: Int64
    let isModifier: Bool
    let displayName: String
}

struct KeyCaptureView: NSViewRepresentable {
    var isCapturing: Bool
    var onCapture: (CapturedKey) -> Void
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
    var onCapture: ((CapturedKey) -> Void)?
    var onCancel: (() -> Void)?

    // Track which modifier flags are currently held so we only fire on key-down
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

        // Determine if this is a key-down (flag newly set) vs key-up (flag cleared)
        let isDown = isModifierKeyDown(keyCode: keyCode, flags: flags)
        previousFlags = flags

        guard isDown else { return }

        let name = KeycodeNames.name(for: keyCode, isModifier: true)
        onCapture?(CapturedKey(keycode: keyCode, isModifier: true, displayName: name))
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = Int64(event.keyCode)

        // Escape cancels capture
        if keyCode == 0x35 {
            onCancel?()
            return
        }

        let name = KeycodeNames.name(for: keyCode, isModifier: false)
        onCapture?(CapturedKey(keycode: keyCode, isModifier: false, displayName: name))
    }

    override func keyUp(with event: NSEvent) {
        // Swallow key-up events during capture to prevent system beep
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
