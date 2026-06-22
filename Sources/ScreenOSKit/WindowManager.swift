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
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier

        let appElement = AXUIElementCreateApplication(pid)
        var focusedValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedValue)

        guard result == .success,
              let focusedElement = focusedValue,
              CFGetTypeID(focusedElement) == AXUIElementGetTypeID()
        else {
            return listAllWindows().first(where: { $0.pid == pid && !$0.isMinimized })
        }

        let axWin = focusedElement as! AXUIElement
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let posVal = posRef, let sizeVal = sizeRef
        else {
            return listAllWindows().first(where: { $0.pid == pid && !$0.isMinimized })
        }

        var axOrigin = CGPoint.zero
        var axSize = CGSize.zero
        guard AXValueGetValue(posVal as! AXValue, .cgPoint, &axOrigin),
              AXValueGetValue(sizeVal as! AXValue, .cgSize, &axSize)
        else {
            return listAllWindows().first(where: { $0.pid == pid && !$0.isMinimized })
        }

        // AX position is Quartz space — same space as ScreenWindow.frame from CGWindowListCopyWindowInfo.
        return listAllWindows().first(where: {
            $0.pid == pid &&
            !$0.isMinimized &&
            abs($0.frame.origin.x - axOrigin.x) < 20 &&
            abs($0.frame.origin.y - axOrigin.y) < 20
        })
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

        // Match window by position heuristic (no direct CGWindowID-to-AXUIElement mapping).
        // AX position is Quartz space — same space as window.frame from CGWindowListCopyWindowInfo.
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
                    if abs(currentFrame.origin.x - window.frame.origin.x) < 20
                       && abs(currentFrame.origin.y - window.frame.origin.y) < 20 {
                        return setAXWindowFrame(frame, for: axWin)
                    }
                }
            }
        }

        return setAXFrame(frame, for: appElement)
    }

    // Converts an AppKit-space frame (Y-up, origin bottom-left of primary screen)
    // to the Quartz-space origin that AX position attributes expect (Y-down, origin top-left).
    func appKitToAXOrigin(_ appKitFrame: CGRect, primaryScreenHeight: CGFloat) -> CGPoint {
        CGPoint(x: appKitFrame.minX, y: primaryScreenHeight - appKitFrame.maxY)
    }

    private func setAXWindowFrame(_ appKitFrame: CGRect, for axWindow: AXUIElement) -> Bool {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var point = appKitToAXOrigin(appKitFrame, primaryScreenHeight: primaryHeight)
        var size = appKitFrame.size

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
        guard let axWindows = windowsValue as? [AXUIElement] else { return }

        for axWin in axWindows {
            var posRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posRef) == .success,
                  let posVal = posRef else { continue }
            var point = CGPoint.zero
            guard AXValueGetValue(posVal as! AXValue, .cgPoint, &point) else { continue }
            if abs(point.x - window.frame.origin.x) < 20 && abs(point.y - window.frame.origin.y) < 20 {
                AXUIElementSetAttributeValue(axWin, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                return
            }
        }
        if let target = axWindows.first {
            AXUIElementSetAttributeValue(target, kAXMinimizedAttribute as CFString, true as CFTypeRef)
        }
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
