import AppKit
import Carbon

/// Controls the window switcher overlay: lifecycle, keyboard navigation, filtering.
final class SwitcherController {

    static let shared = SwitcherController()

    private let panel = SwitcherPanel()
    private var isActive = false

    private init() {
        panel.onWindowSelected = { [weak self] window in
            self?.selectWindow(window)
        }
    }

    /// Shows the window switcher overlay.
    func show() {
        guard !isActive else { return }

        let windows = WindowManager.shared.listAllWindows()

        guard !windows.isEmpty else {
            NSSound.beep()
            return
        }

        isActive = true
        panel.show(with: windows)

        // Start a local event monitor for keyboard navigation
        startKeyboardMonitor()
    }

    /// Dismisses the switcher.
    func dismiss() {
        isActive = false
        panel.closePanel()
        stopKeyboardMonitor()
    }

    /// Selects a window and switches to it.
    private func selectWindow(_ window: ScreenWindow) {
        WindowManager.shared.focus(window: window)
        dismiss()
    }

    // MARK: - Keyboard Monitoring

    private var keyboardMonitor: Any?

    private func startKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isActive else { return event }

            switch Int(event.keyCode) {
            case Int(kVK_LeftArrow), Int(kVK_RightArrow):
                // Navigate between items
                if event.keyCode == kVK_LeftArrow {
                    self.panel.navigatePrevious()
                } else {
                    self.panel.navigateNext()
                }
                return nil

            case Int(kVK_Return), Int(kVK_Space):
                // Select current item
                if let window = self.panel.selectCurrent() {
                    self.selectWindow(window)
                }
                return nil

            case Int(kVK_Escape):
                // Dismiss without switching
                self.dismiss()
                return nil

            case Int(kVK_ANSI_Grave):
                // Cmd+` — next window (already handled by hotkey, but handle pure ` too)
                if event.modifierFlags.contains(.command) {
                    self.panel.navigateNext()
                    return nil
                }
                return event

            default:
                return event
            }
        }
    }

    private func stopKeyboardMonitor() {
        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }
    }

    /// Returns whether the switcher is currently showing.
    var isShowing: Bool { isActive }
}
