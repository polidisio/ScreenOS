import AppKit
import Carbon

/// A control that records a keyboard shortcut.
/// Displays the current shortcut and captures a new one when clicked.
final class ShortcutRecorder: NSButton {

    // MARK: - Types

    struct Shortcut: Codable, Equatable {
        let keyCode: UInt16
        let flags: UInt32  // Carbon modifier flags

        var displayString: String {
            var parts: [String] = []

            if flags & UInt32(cmdKey) != 0 { parts.append("⌘") }
            if flags & UInt32(optionKey) != 0 { parts.append("⌥") }
            if flags & UInt32(shiftKey) != 0 { parts.append("⇧") }
            if flags & UInt32(controlKey) != 0 { parts.append("⌃") }

            if let keyName = keyName(for: keyCode) {
                parts.append(keyName)
            }

            return parts.joined()
        }

        private func keyName(for keyCode: UInt16) -> String? {
        // kVK codes are not sequential for letters or digits on all layouts,
        // but ANSI is the most common. We use a safe mapping.
        let key: String
        switch Int(keyCode) {
        // Letters (ANSI)
        case 0x00: key = "A"
        case 0x01: key = "S"
        case 0x02: key = "D"
        case 0x03: key = "F"
        case 0x04: key = "H"
        case 0x05: key = "G"
        case 0x06: key = "Z"
        case 0x07: key = "X"
        case 0x08: key = "C"
        case 0x09: key = "V"
        case 0x0B: key = "B"
        case 0x0C: key = "Q"
        case 0x0D: key = "W"
        case 0x0E: key = "E"
        case 0x0F: key = "R"
        case 0x10: key = "Y"
        case 0x11: key = "T"
        case 0x12: key = "1"
        case 0x13: key = "2"
        case 0x14: key = "3"
        case 0x15: key = "4"
        case 0x16: key = "6"
        case 0x17: key = "5"
        case 0x18: key = "="
        case 0x19: key = "9"
        case 0x1A: key = "7"
        case 0x1B: key = "-"
        case 0x1C: key = "8"
        case 0x1D: key = "0"
        case 0x1E: key = "]"
        case 0x1F: key = "O"
        case 0x20: key = "U"
        case 0x21: key = "["
        case 0x22: key = "I"
        case 0x23: key = "P"
        case kVK_ANSI_Grave: key = "`"
        case kVK_ANSI_Semicolon: key = ";"
        case kVK_ANSI_Quote: key = "'"
        case kVK_ANSI_Comma: key = ","
        case kVK_ANSI_Period: key = "."
        case kVK_ANSI_Slash: key = "/"
        case kVK_ANSI_Backslash: key = "\\"
        // Navigation
        case kVK_LeftArrow: key = "←"
        case kVK_RightArrow: key = "→"
        case kVK_UpArrow: key = "↑"
        case kVK_DownArrow: key = "↓"
        // Special
        case kVK_Space: key = "Espacio"
        case kVK_Escape: key = "Esc"
        case kVK_Return: key = "Return"
        case kVK_Tab: key = "Tab"
        case kVK_Delete: key = "⌫"
        // Function keys
        case kVK_F1: key = "F1"
        case kVK_F2: key = "F2"
        case kVK_F3: key = "F3"
        case kVK_F4: key = "F4"
        case kVK_F5: key = "F5"
        case kVK_F6: key = "F6"
        case kVK_F7: key = "F7"
        case kVK_F8: key = "F8"
        case kVK_F9: key = "F9"
        case kVK_F10: key = "F10"
        case kVK_F11: key = "F11"
        case kVK_F12: key = "F12"
        default: return "Key\(keyCode)"
        }
        return key
    }
    }

    // MARK: - Properties

    var shortcut: Shortcut? {
        didSet {
            updateDisplay()
        }
    }

    var onShortcutChanged: ((Shortcut) -> Void)?

    private var isRecording = false

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
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
            title = "Pulsa la combinación..."
            window?.makeFirstResponder(self)
        } else {
            updateDisplay()
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode

        // Ignore standalone modifier keys
        let modifierKeys: Set<UInt16> = [UInt16(kVK_Command), UInt16(kVK_Shift), UInt16(kVK_Option), UInt16(kVK_Control),
                                          UInt16(kVK_RightCommand), UInt16(kVK_RightShift), UInt16(kVK_RightOption), UInt16(kVK_RightControl),
                                          UInt16(kVK_CapsLock), UInt16(kVK_Function)]
        if modifierKeys.contains(keyCode) {
            return
        }

        let flags = event.carbonModifierFlags()

        let newShortcut = Shortcut(keyCode: keyCode, flags: flags)
        shortcut = newShortcut
        onShortcutChanged?(newShortcut)

        isRecording = false
        updateDisplay()
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            updateDisplay()
        }
        return true
    }

    // MARK: - Display

    private func updateDisplay() {
        if let shortcut = shortcut {
            title = shortcut.displayString
        } else {
            title = "Grabar atajo..."
        }
    }
}

// MARK: - NSEvent Extensions for Carbon modifiers

extension NSEvent {
    func carbonModifierFlags() -> UInt32 {
        var carbon: UInt32 = 0
        let flags = modifierFlags
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}
