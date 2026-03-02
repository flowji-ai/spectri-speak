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

    private func isModifierKeyDown(keyCode: Int64, flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 0x3A, 0x3D: // Left/Right Option
            return flags.contains(.option) && !previousFlags.contains(.option)
                || (flags.contains(.option) && previousFlags.contains(.option) == false)
        case 0x37, 0x36: // Left/Right Command
            return flags.contains(.command) && !previousFlags.contains(.command)
                || (flags.contains(.command) && previousFlags.contains(.command) == false)
        case 0x38, 0x3C: // Left/Right Shift
            return flags.contains(.shift) && !previousFlags.contains(.shift)
                || (flags.contains(.shift) && previousFlags.contains(.shift) == false)
        case 0x3B, 0x3E: // Left/Right Control
            return flags.contains(.control) && !previousFlags.contains(.control)
                || (flags.contains(.control) && previousFlags.contains(.control) == false)
        case 0x3F: // Fn
            return flags.contains(.function) && !previousFlags.contains(.function)
        default:
            return false
        }
    }
}

enum KeycodeNames {
    static func name(for keycode: Int64, isModifier: Bool) -> String {
        if isModifier {
            switch keycode {
            case 0x37: return "Left Command"
            case 0x36: return "Right Command"
            case 0x3A: return "Left Option"
            case 0x3D: return "Right Option"
            case 0x38: return "Left Shift"
            case 0x3C: return "Right Shift"
            case 0x3B: return "Left Control"
            case 0x3E: return "Right Control"
            case 0x3F: return "Fn"
            default: return "Modifier \(keycode)"
            }
        }

        switch keycode {
        case 0x31: return "Space"
        case 0x24: return "Return"
        case 0x30: return "Tab"
        case 0x33: return "Delete"
        case 0x75: return "Forward Delete"
        case 0x7A: return "F1"
        case 0x78: return "F2"
        case 0x63: return "F3"
        case 0x76: return "F4"
        case 0x60: return "F5"
        case 0x61: return "F6"
        case 0x62: return "F7"
        case 0x64: return "F8"
        case 0x65: return "F9"
        case 0x6D: return "F10"
        case 0x67: return "F11"
        case 0x6F: return "F12"
        case 0x69: return "F13"
        case 0x6B: return "F14"
        case 0x71: return "F15"
        case 0x7E: return "Up Arrow"
        case 0x7D: return "Down Arrow"
        case 0x7B: return "Left Arrow"
        case 0x7C: return "Right Arrow"
        case 0x73: return "Home"
        case 0x77: return "End"
        case 0x74: return "Page Up"
        case 0x79: return "Page Down"
        case 0x00: return "A"
        case 0x0B: return "B"
        case 0x08: return "C"
        case 0x02: return "D"
        case 0x0E: return "E"
        case 0x03: return "F"
        case 0x05: return "G"
        case 0x04: return "H"
        case 0x22: return "I"
        case 0x26: return "J"
        case 0x28: return "K"
        case 0x25: return "L"
        case 0x2E: return "M"
        case 0x2D: return "N"
        case 0x1F: return "O"
        case 0x23: return "P"
        case 0x0C: return "Q"
        case 0x0F: return "R"
        case 0x01: return "S"
        case 0x11: return "T"
        case 0x20: return "U"
        case 0x09: return "V"
        case 0x0D: return "W"
        case 0x07: return "X"
        case 0x10: return "Y"
        case 0x06: return "Z"
        case 0x12: return "1"
        case 0x13: return "2"
        case 0x14: return "3"
        case 0x15: return "4"
        case 0x17: return "5"
        case 0x16: return "6"
        case 0x1A: return "7"
        case 0x1C: return "8"
        case 0x19: return "9"
        case 0x1D: return "0"
        case 0x1B: return "-"
        case 0x18: return "="
        case 0x21: return "["
        case 0x1E: return "]"
        case 0x2A: return "\\"
        case 0x29: return ";"
        case 0x27: return "'"
        case 0x2B: return ","
        case 0x2F: return "."
        case 0x2C: return "/"
        case 0x32: return "`"
        default: return "Key \(keycode)"
        }
    }
}
