import AppKit
import ApplicationServices

/// Model representing a single window on screen.
public struct ScreenWindow: Identifiable, Hashable {
    public let id: CGWindowID
    public let pid: pid_t
    public let appName: String
    public let appIcon: NSImage?
    public let title: String
    public let frame: CGRect
    public let layer: UInt32
    public let isMinimized: Bool
    public let isOnScreen: Bool
    public let axElement: AXUIElement?

    public static func == (lhs: ScreenWindow, rhs: ScreenWindow) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
