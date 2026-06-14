import AppKit
import ApplicationServices

/// Handles the Show Desktop / Hide Windows toggle feature.
public final class ShowDesktopManager {

    public static let shared = ShowDesktopManager()

    private var isShowingDesktop = false
    private var savedWindows: [ScreenWindow] = []

    private init() {}

    public func toggle() {
        if isShowingDesktop {
            restoreWindows()
        } else {
            hideAllWindows()
        }
    }

    public var isActive: Bool { isShowingDesktop }

    private func hideAllWindows() {
        savedWindows = []
        let windows = WindowManager.shared.listAllWindows()

        for window in windows {
            let app = NSRunningApplication(processIdentifier: window.pid)
            if app?.bundleIdentifier == "com.apple.finder" { continue }

            let appElement = AXUIElementCreateApplication(window.pid)
            var windowsValue: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

            guard result == .success,
                  let axWindows = windowsValue as? [AXUIElement],
                  let firstWindow = axWindows.first
            else { continue }

            var minimizedValue: CFTypeRef?
            AXUIElementCopyAttributeValue(firstWindow, kAXMinimizedAttribute as CFString, &minimizedValue)
            let isMinimized = (minimizedValue as? Bool) ?? false

            if !isMinimized {
                // Save before minimizing so we can restore later
                savedWindows.append(window)
                AXUIElementSetAttributeValue(firstWindow, kAXMinimizedAttribute as CFString, true as CFTypeRef)
            }
        }

        isShowingDesktop = true
    }

    private func restoreWindows() {
        for window in savedWindows {
            guard let axElement = window.axElement else { continue }
            AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }
        savedWindows = []
        isShowingDesktop = false
    }
}
