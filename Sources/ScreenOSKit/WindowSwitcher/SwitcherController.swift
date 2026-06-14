import AppKit
import Carbon

/// Controls the window switcher overlay: lifecycle, keyboard navigation, and filtering.
public final class SwitcherController {

    public static let shared = SwitcherController()

    private let panel = SwitcherPanel()
    private var isActive = false

    private init() {
        panel.onWindowSelected = { [weak self] window in
            self?.selectWindow(window)
        }
    }

    /// Shows the window switcher overlay.
    public func show() {
        guard !isActive else { return }

        let windows = WindowManager.shared.listAllWindows()

        guard !windows.isEmpty else {
            NSSound.beep()
            return
        }

        isActive = true
        panel.show(with: windows)
        startKeyboardMonitor()
    }

    /// Dismisses the switcher without switching windows.
    public func dismiss() {
        isActive = false
        panel.closePanel()
        stopKeyboardMonitor()
    }

    /// Returns whether the switcher is currently showing.
    public var isShowing: Bool { isActive }

    // MARK: - Window selection

    private func selectWindow(_ window: ScreenWindow) {
        WindowManager.shared.focus(window: window)
        dismiss()
    }

    // MARK: - Keyboard monitoring

    private var keyboardMonitor: Any?

    private func startKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isActive else { return event }

            switch event.keyCode {
            case UInt16(kVK_LeftArrow):
                self.panel.navigatePrevious()
                return nil

            case UInt16(kVK_RightArrow):
                self.panel.navigateNext()
                return nil

            case UInt16(kVK_Return), UInt16(kVK_Space):
                if let window = self.panel.selectCurrent() {
                    self.selectWindow(window)
                }
                return nil

            case UInt16(kVK_Escape):
                self.dismiss()
                return nil

            case UInt16(kVK_ANSI_Grave) where event.modifierFlags.contains(.command):
                self.panel.navigateNext()
                return nil

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
}
