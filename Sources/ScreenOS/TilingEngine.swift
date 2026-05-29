import AppKit

/// Calculates window frame positions for tiling operations.
///
/// Supports: left, right, top, bottom, top-left, top-right, bottom-left,
/// bottom-right, center, and maximize — all relative to the current screen.
final class TilingEngine {

    enum TilingPosition: String, CaseIterable {
        case left, right, top, bottom
        case topLeft, topRight, bottomLeft, bottomRight
        case center, maximize
    }

    static let shared = TilingEngine()

    private init() {}

    /// Returns the suggested frame for a window at a given tiling position.
    /// - Parameters:
    ///   - position: The target position
    ///   - currentFrame: The window's current frame (for fallback)
    ///   - screen: The screen the window is on
    /// - Returns: The new CGRect for the window
    func frame(for position: TilingPosition, currentFrame: CGRect, screen: NSScreen) -> CGRect {
        let screenFrame = screen.visibleFrame  // excludes menu bar & dock

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
    func screen(for frame: CGRect) -> NSScreen {
        let screens = NSScreen.screens

        // Find the screen that contains most of the window
        let candidates = screens.map { screen -> (screen: NSScreen, overlap: CGFloat) in
            let intersection = screen.visibleFrame.intersection(frame)
            return (screen, intersection.width * intersection.height)
        }

        if let best = candidates.max(by: { $0.overlap < $1.overlap }), best.overlap > 0 {
            return best.screen
        }

        // Fallback to main screen
        return NSScreen.main ?? screens.first ?? NSScreen()
    }

    /// Applies a tiling position to the currently focused window.
    func applyPosition(_ position: TilingPosition) {
        guard let focusedWindow = WindowManager.shared.focusedWindow() else {
            NSSound.beep()
            return
        }

        let screen = self.screen(for: focusedWindow.frame)
        let newFrame = frame(for: position, currentFrame: focusedWindow.frame, screen: screen)

        WindowManager.shared.setFrame(newFrame, for: focusedWindow)
    }
}
