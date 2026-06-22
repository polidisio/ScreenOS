import AppKit
import ApplicationServices

/// Handles the Show Desktop / Hide Windows toggle feature.
public final class ShowDesktopManager {

    public static let shared = ShowDesktopManager()

    private var isShowingDesktop = false
    private var savedWindows: [ScreenWindow] = []
    private var savedAxWindows: [AXUIElement] = []

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
        savedAxWindows = []
        var seenPIDs = Set<pid_t>()
        let windows = WindowManager.shared.listAllWindows()

        for window in windows {
            let app = NSRunningApplication(processIdentifier: window.pid)
            if app?.bundleIdentifier == "com.apple.finder" { continue }
            guard !seenPIDs.contains(window.pid) else { continue }
            seenPIDs.insert(window.pid)

            let appElement = AXUIElementCreateApplication(window.pid)
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let axWindows = windowsValue as? [AXUIElement]
            else { continue }

            for axWin in axWindows {
                var minimizedValue: CFTypeRef?
                AXUIElementCopyAttributeValue(axWin, kAXMinimizedAttribute as CFString, &minimizedValue)
                let isMinimized = (minimizedValue as? Bool) ?? false

                if !isMinimized {
                    savedAxWindows.append(axWin)
                    AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                }
            }
        }

        savedWindows = windows
        isShowingDesktop = true
    }

    private func restoreWindows() {
        // Restore using window-level AX elements, not app-level elements.
        for axWin in savedAxWindows {
            AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, false as CFTypeRef)
        }
        savedWindows = []
        savedAxWindows = []
        isShowingDesktop = false
    }
}
