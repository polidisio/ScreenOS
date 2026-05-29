import AppKit
import ApplicationServices

/// Model representing a single window on screen.
struct ScreenWindow: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let appIcon: NSImage?
    let title: String
    let frame: CGRect
    let layer: UInt32
    let isMinimized: Bool
    let isOnScreen: Bool
    let axElement: AXUIElement?

    static func == (lhs: ScreenWindow, rhs: ScreenWindow) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
