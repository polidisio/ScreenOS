import AppKit

/// Calculates window frame positions for tiling operations.
///
/// Supports: left, right, top, bottom, top-left, top-right, bottom-left,
/// bottom-right, center, and maximize — all relative to the current screen.
public final class TilingEngine {

    public enum TilingPosition: String, CaseIterable {
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
        case center, maximize
    }

    public static let shared = TilingEngine()

    private init() {}

    /// Returns the suggested frame for a window at a given tiling position.
    public func frame(for position: TilingPosition, currentFrame: CGRect, screen: NSScreen) -> CGRect {
        frame(for: position, currentFrame: currentFrame, screenFrame: screen.visibleFrame)
    }

    /// Returns the suggested frame using a raw screen rect.
    /// Overload used by tests so they don't need a live NSScreen.
    ///
    /// macOS coordinate system: origin at bottom-left, Y increases upward.
    /// "top" positions use higher Y values (screenFrame.midY ... screenFrame.maxY).
    public func frame(for position: TilingPosition, currentFrame: CGRect, screenFrame: CGRect) -> CGRect {
        switch position {
        case .left:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )

        case .right:
            return CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height
            )

        case .top:
            // Higher Y = upper half in macOS coordinates
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.midY,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )

        case .bottom:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width,
                height: screenFrame.height / 2
            )

        case .topLeft:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.midY,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        case .topRight:
            return CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.midY,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        case .bottomLeft:
            return CGRect(
                x: screenFrame.minX,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        case .bottomRight:
            return CGRect(
                x: screenFrame.minX + screenFrame.width / 2,
                y: screenFrame.minY,
                width: screenFrame.width / 2,
                height: screenFrame.height / 2
            )

        case .center:
            let width = screenFrame.width * 0.6
            let height = screenFrame.height * 0.8
            return CGRect(
                x: screenFrame.minX + (screenFrame.width - width) / 2,
                y: screenFrame.minY + (screenFrame.height - height) / 2,
                width: width,
                height: height
            )

        case .maximize:
            return screenFrame
        }
    }

    /// Determines which screen a window is on based on its frame.
    /// - Parameter quartzFrame: Window frame in Quartz space (Y-down) as returned by CGWindowListCopyWindowInfo.
    public func screen(for quartzFrame: CGRect) -> NSScreen {
        let screens = NSScreen.screens
        let primaryHeight = screens.first?.frame.height ?? 0

        // CGWindowListCopyWindowInfo returns Quartz-space frames (Y-down, origin top-left).
        // NSScreen.visibleFrame uses AppKit space (Y-up, origin bottom-left). Convert before intersecting.
        let appKitFrame = CGRect(
            x: quartzFrame.minX,
            y: primaryHeight - quartzFrame.maxY,
            width: quartzFrame.width,
            height: quartzFrame.height
        )

        let candidates = screens.map { screen -> (screen: NSScreen, overlap: CGFloat) in
            let intersection = screen.visibleFrame.intersection(appKitFrame)
            return (screen, intersection.width * intersection.height)
        }

        if let best = candidates.max(by: { $0.overlap < $1.overlap }), best.overlap > 0 {
            return best.screen
        }

        return NSScreen.main ?? screens.first ?? NSScreen()
    }

    /// Applies a tiling position to the currently focused window.
    public func applyPosition(_ position: TilingPosition) {
        DispatchQueue.main.async { [self] in
            guard let focusedWindow = WindowManager.shared.focusedWindow() else {
                NSSound.beep()
                return
            }

            let screen = self.screen(for: focusedWindow.frame)
            let newFrame = frame(for: position, currentFrame: focusedWindow.frame, screen: screen)
            WindowManager.shared.setFrame(newFrame, for: focusedWindow)
        }
    }
}
