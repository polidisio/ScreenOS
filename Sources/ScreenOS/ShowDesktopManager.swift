import AppKit
import ApplicationServices

/// Handles the Show Desktop / Hide Windows toggle feature.
final class ShowDesktopManager {

    static let shared = ShowDesktopManager()

    private var isShowingDesktop = false
    private var savedWindows: [ScreenWindow] = []

    private init() {}

    func toggle() {
        if isShowingDesktop {
            restoreWindows()
        } else {
            hideAllWindows()
        }
    }

    var isActive: Bool { isShowingDesktop }

    private func hideAllWindows() {
        let windows = WindowManager.shared.listAllWindows()
        print("[ShowDesktopManager] Found \(windows.count) windows")

        for window in windows {
            // Skip Finder
            let app = NSRunningApplication(processIdentifier: window.pid)
            if app?.bundleIdentifier == "com.apple.finder" {
                print("[ShowDesktopManager] Skipping Finder")
                continue
            }

            // Get the app's AXUIElement
            let appElement = AXUIElementCreateApplication(window.pid)

            // Get the windows array
            var windowsValue: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

            guard result == .success,
                  let axWindows = windowsValue as? [AXUIElement],
                  let firstWindow = axWindows.first
            else {
                print("[ShowDesktopManager] Could not get windows for \(window.appName)")
                continue
            }

            // Check if already minimized
            var minimizedValue: CFTypeRef?
            AXUIElementCopyAttributeValue(firstWindow, "AXMinimized" as CFString, &minimizedValue)
            let isMinimized = (minimizedValue as? Bool) ?? false

            if !isMinimized {
                print("[ShowDesktopManager] Minimizing window: \(window.title)")
                let setResult = AXUIElementSetAttributeValue(firstWindow, "AXMinimized" as CFString, true as CFTypeRef)
                print("[ShowDesktopManager] Set result: \(setResult.rawValue)")
            }
        }

        print("[ShowDesktopManager] Done hiding windows")
    }

    private func restoreWindows() {
        for window in savedWindows {
            guard let axElement = window.axElement else { continue }
            AXUIElementSetAttributeValue(axElement, "AXMinimized" as CFString, false as CFTypeRef)
        }
        savedWindows = []
        isShowingDesktop = false
    }
}