import AppKit
import ApplicationServices

/// Handles all window listing and manipulation via AXUIElement / CGWindow APIs.
public final class WindowManager {

    public static let shared = WindowManager()

    private init() {}

    /// Returns all visible, non-system windows on the current Space.
    public func listAllWindows() -> [ScreenWindow] {
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
    public func focusedWindow() -> ScreenWindow? {
        let app = NSWorkspace.shared.frontmostApplication
        guard let pid = app?.processIdentifier else { return nil }

        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedValue)
        guard result == .success,
              let focusedElement = focusedValue,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID()
        else {
            return listAllWindows().first(where: { $0.pid == pid && !$0.isMinimized })
        }

        let windows = listAllWindows().filter { $0.pid == pid && !$0.isMinimized }
        return windows.first
    }

    /// Sets the position and size of a window using the AX API.
    @discardableResult
    public func setFrame(_ frame: CGRect, for window: ScreenWindow) -> Bool {
        let appElement = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)

        guard result == .success,
              let windows = windowsValue as? [AXUIElement]
        else {
            return setAXFrame(frame, for: appElement)
        }

        // Match window by position heuristic (no direct CGWindowID-to-AXUIElement mapping)
        for axWin in windows {
            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            let posResult = AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &positionValue)
            let sizeResult = AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeValue)

            if posResult == .success, sizeResult == .success {
                var point = CGPoint.zero
                var sizeRect = CGSize.zero
                if AXValueGetValue(positionValue! as! AXValue, .cgPoint, &point),
                   AXValueGetValue(sizeValue! as! AXValue, .cgSize, &sizeRect) {
                    let currentFrame = CGRect(origin: point, size: sizeRect)
                    if abs(currentFrame.origin.x - window.frame.origin.x) < 5 {
                        return setAXWindowFrame(frame, for: axWin)
                    }
                }
            }
        }

        return setAXFrame(frame, for: appElement)
    }

    private func setAXWindowFrame(_ frame: CGRect, for axWindow: AXUIElement) -> Bool {
        var point = frame.origin
        var size = frame.size

        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return false }

        let posResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, pointValue)
        let sizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)

        return posResult == .success && sizeResult == .success
    }

    private func setAXFrame(_ frame: CGRect, for appElement: AXUIElement) -> Bool {
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement], let target = windows.first
        else { return false }
        return setAXWindowFrame(frame, for: target)
    }

    /// Minimizes a window.
    public func minimize(window: ScreenWindow) {
        let app = AXUIElementCreateApplication(window.pid)
        var windowsValue: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsValue)
        guard let windows = windowsValue as? [AXUIElement], let target = windows.first else { return }
        AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, true as CFTypeRef)
    }

    /// Brings a window to front and activates its application.
    public func raise(window: ScreenWindow) {
        let app = NSRunningApplication(processIdentifier: window.pid)
        app?.activate(options: [])

        guard let ax = window.axElement else { return }
        AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
    }

    /// Focuses a window (activates its app + raises it).
    public func focus(window: ScreenWindow) {
        raise(window: window)
    }
}
