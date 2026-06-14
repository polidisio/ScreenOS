import AppKit
import Carbon

/// A control that records a keyboard shortcut.
/// Displays the current shortcut and captures a new one when clicked.
public final class ShortcutRecorder: NSButton {

    // MARK: - Types

    public struct Shortcut: Codable, Equatable {
        public let keyCode: UInt16
        public let flags: UInt32  // Carbon modifier flags

        public init(keyCode: UInt16, flags: UInt32) {
            self.keyCode = keyCode
            self.flags = flags
        }

        public var displayString: String {
            var parts: [String] = []
            if flags & UInt32(cmdKey)     != 0 { parts.append("⌘") }
            if flags & UInt32(optionKey)  != 0 { parts.append("⌥") }
            if flags & UInt32(shiftKey)   != 0 { parts.append("⇧") }
            if flags & UInt32(controlKey) != 0 { parts.append("⌃") }
            if let name = keyName(for: keyCode) { parts.append(name) }
            return parts.joined()
        }

        // Maps ANSI virtual key codes (from HIToolbox/Events.h) to display names.
        // Values are in ANSI keyboard order, NOT alphabetical order.
        private func keyName(for keyCode: UInt16) -> String? {
            switch keyCode {
            // ── Letters (ANSI layout positions, not alphabetical) ──────────
            case 0x00: return "A"
            case 0x01: return "S"
            case 0x02: return "D"
            case 0x03: return "F"
            case 0x04: return "H"
            case 0x05: return "G"
            case 0x06: return "Z"
            case 0x07: return "X"
            case 0x08: return "C"
            case 0x09: return "V"
            case 0x0B: return "B"
            case 0x0C: return "Q"
            case 0x0D: return "W"
            case 0x0E: return "E"
            case 0x0F: return "R"
            case 0x10: return "Y"
            case 0x11: return "T"
            case 0x1F: return "O"
            case 0x20: return "U"
            case 0x22: return "I"
            case 0x23: return "P"
            case 0x25: return "L"
            case 0x26: return "J"
            case 0x28: return "K"
            case 0x2D: return "N"
            case 0x2E: return "M"
            // ── Digits ──────────────────────────────────────────────────────
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
            // ── Punctuation / symbols ────────────────────────────────────────
            case UInt16(kVK_ANSI_Minus):        return "-"
            case UInt16(kVK_ANSI_Equal):        return "="
            case UInt16(kVK_ANSI_LeftBracket):  return "["
            case UInt16(kVK_ANSI_RightBracket): return "]"
            case UInt16(kVK_ANSI_Backslash):    return "\\"
            case UInt16(kVK_ANSI_Semicolon):    return ";"
            case UInt16(kVK_ANSI_Quote):        return "'"
            case UInt16(kVK_ANSI_Grave):        return "`"
            case UInt16(kVK_ANSI_Comma):        return ","
            case UInt16(kVK_ANSI_Period):       return "."
            case UInt16(kVK_ANSI_Slash):        return "/"
            // ── Special keys ─────────────────────────────────────────────────
            case UInt16(kVK_Space):         return "Space"
            case UInt16(kVK_Return):        return "↩"
            case UInt16(kVK_Tab):           return "⇥"
            case UInt16(kVK_Delete):        return "⌫"
            case UInt16(kVK_ForwardDelete): return "⌦"
            case UInt16(kVK_Escape):        return "Esc"
            // ── Navigation ───────────────────────────────────────────────────
            case UInt16(kVK_LeftArrow):  return "←"
            case UInt16(kVK_RightArrow): return "→"
            case UInt16(kVK_UpArrow):    return "↑"
            case UInt16(kVK_DownArrow):  return "↓"
            case UInt16(kVK_Home):       return "↖"
            case UInt16(kVK_End):        return "↘"
            case UInt16(kVK_PageUp):     return "⇞"
            case UInt16(kVK_PageDown):   return "⇟"
            // ── Function keys ─────────────────────────────────────────────────
            case UInt16(kVK_F1):  return "F1"
            case UInt16(kVK_F2):  return "F2"
            case UInt16(kVK_F3):  return "F3"
            case UInt16(kVK_F4):  return "F4"
            case UInt16(kVK_F5):  return "F5"
            case UInt16(kVK_F6):  return "F6"
            case UInt16(kVK_F7):  return "F7"
            case UInt16(kVK_F8):  return "F8"
            case UInt16(kVK_F9):  return "F9"
            case UInt16(kVK_F10): return "F10"
            case UInt16(kVK_F11): return "F11"
            case UInt16(kVK_F12): return "F12"
            default: return "Key\(keyCode)"
            }
        }
    }

    // MARK: - Properties

    public var shortcut: Shortcut? {
        didSet { updateDisplay() }
    }

    public var onShortcutChanged: ((Shortcut) -> Void)?
    private var isRecording = false

    // MARK: - Init

    public override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        bezelStyle = .rounded
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        target = self
        action = #selector(startRecording)
        updateDisplay()
    }

    // MARK: - Recording

    @objc private func startRecording() {
        isRecording.toggle()
        if isRecording {
            title = "Press shortcut..."
            window?.makeFirstResponder(self)
        } else {
            updateDisplay()
        }
    }

    public override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifierKeyCodes: Set<UInt16> = [
            UInt16(kVK_Command), UInt16(kVK_Shift), UInt16(kVK_Option), UInt16(kVK_Control),
            UInt16(kVK_RightCommand), UInt16(kVK_RightShift), UInt16(kVK_RightOption), UInt16(kVK_RightControl),
            UInt16(kVK_CapsLock), UInt16(kVK_Function)
        ]
        guard !modifierKeyCodes.contains(event.keyCode) else { return }

        let flags = event.carbonModifierFlags()
        let newShortcut = Shortcut(keyCode: event.keyCode, flags: flags)
        shortcut = newShortcut
        onShortcutChanged?(newShortcut)
        isRecording = false
        updateDisplay()
    }

    public override var acceptsFirstResponder: Bool { true }

    public override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            updateDisplay()
        }
        return true
    }

    // MARK: - Display

    private func updateDisplay() {
        title = shortcut?.displayString ?? "Record shortcut..."
    }
}

// MARK: - NSEvent + Carbon modifier conversion

extension NSEvent {
    public func carbonModifierFlags() -> UInt32 {
        var carbon: UInt32 = 0
        if modifierFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifierFlags.contains(.option)  { carbon |= UInt32(optionKey) }
        if modifierFlags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if modifierFlags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}
