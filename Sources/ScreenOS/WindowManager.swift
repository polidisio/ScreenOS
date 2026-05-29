import AppKit
import ApplicationServices

/// Handles all window listing and manipulation via AXUIElement / CGWindow APIs.
final class WindowManager {

    static let shared = WindowManager()

    private init() {}

    /// Returns all visible, non-system windows on the current Space.
    func listAllWindows() -> [ScreenWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        var results: [ScreenWindow] = []

        for entry in windowList {
            guard let windowID = entry[kCGWindowNumber as String] as? UInt32,
                  let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                  let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = entry[kCGWindowLayer as String] as? UInt32,
                  let title = entry[kCGWindowName as String] as? String,
                  !title.isEmpty
            else { continue }

            // Skip system windows (dock, menubar, desktop icons)
            guard layer < 27 else { continue }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            let app = NSRunningApplication(processIdentifier: pid)
            let isMinimized = bounds.isEmpty

            let axElement = AXUIElementCreateApplication(pid)
            let window = ScreenWindow(
                id: windowID,
                pid: pid,
                appName: app?.localizedName ?? "Unknown",
                appIcon: app?.icon,
                title: title,
                frame: bounds,
                layer: layer,
                isMinimized: isMinimized,
                isOnScreen: !isMinimized,
                axElement: axElement
            )
            results.append(window)
        }

        return results.sorted { $0.layer < $1.layer }
    }

    /// Returns the currently focused window (the one with keyboard focus).
    func focusedWindow() -> ScreenWindow? {
        let app = NSWorkspace.shared.frontmostApplication
        guard let pid = app?.processIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedValue)
        guard result == .success,
              let focusedElement = focusedValue,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID()
        else {
            // Fallback: return first visible window of frontmost app
            return listAllWindows().first(where: { $0.pid == pid && !$0.isMinimized })
        }

        // Find the window in our list by matching the AXUIElement
        let windows = listAllWindows().filter { $0.pid == pid && !$0.isMinimized }
        return windows.first
    }

    /// Sets the position and size of a window using AX API.
    @discardableResult
    func setFrame(_ frame: CGRect, for window: ScreenWindow) -> Bool {
        guard window.axElement != nil else {
            // Fallback: try the per-application element
            let appElement = AXUIElementCreateApplication(window.pid)
            return setAXFrame(frame, for: appElement, windowID: window.id)
        }

        // Find the specific AXWindow among the app's children
        let appElement = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        guard result == .success,
              let windows = windowsValue as? [AXUIElement]
        else {
            return setAXFrame(frame, for: appElement, windowID: window.id)
        }

        // Find window by position heuristic (no direct way to match CGWindowID to AXUIElement)
        for axWin in windows {
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            let posResult = AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &positionValue)
            let sizeResult = AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeValue)

            if posResult == .success, let pos = positionValue,
               sizeResult == .success, let size = sizeValue {
                var point = CGPoint.zero
                var sizeRect = CGSize.zero
                if AXValueGetValue(pos as! AXValue, .cgPoint, &point),
                   AXValueGetValue(size as! AXValue, .cgSize, &sizeRect) {
                    let currentFrame = CGRect(origin: point, size: sizeRect)
                    if currentFrame.origin == window.frame.origin
                        || abs(currentFrame.origin.x - window.frame.origin.x) < 5 {
                        return setFrame(frame, for: axWin)
                    }
                }
            }
        }

        return setAXFrame(frame, for: appElement, windowID: window.id)
    }

    private func setFrame(_ frame: CGRect, for axWindow: AXUIElement) -> Bool {
        var point = frame.origin
        var size = frame.size

        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return false }

        let posResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, pointValue)
        let sizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)

        return posResult == .success && sizeResult == .success
    }

    /// Fallback: set frame using CGWarpMouseCursorPosition hint + resize from app element
    private func setAXFrame(_ frame: CGRect, for appElement: AXUIElement, windowID: CGWindowID) -> Bool {
        // List windows from this app and try to match by ID
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement], let target = windows.first
        else { return false }

        return setFrame(frame, for: target)
    }

    /// Minimizes a window.
    func minimize(window: ScreenWindow) {
        guard window.axElement != nil else { return }
        let app = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue)
        guard let windows = windowsValue as? [AXUIElement], let target = windows.first else { return }
        AXUIElementSetAttributeValue(target, "AXMinimized" as CFString, true as CFTypeRef)
    }

    /// Brings a window to front.
    func raise(window: ScreenWindow) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        app?.activate(options: [])

        guard let ax = window.axElement else { return }
        AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
    }

    /// Focuses a window (activates its app + raises it).
    func focus(window: ScreenWindow) {
        raise(window: window)
    }
}
