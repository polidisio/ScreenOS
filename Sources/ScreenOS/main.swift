import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()

        // Request accessibility permission
        requestAccessibilityPermission()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        let alert = NSAlert()
        alert.messageText = "Permissions"
        alert.informativeText = trusted ? "Accessibility: GRANTED" : "Accessibility: NOT YET - Please enable in System Settings"
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = ""
            // Load custom PNG icon
            let iconPath = "/Users/clot/Projects/ScreenOS/Resources/AppIcon.png"
            if let iconImage = NSImage(contentsOfFile: iconPath) {
                button.image = iconImage
            } else {
                button.title = "SO"
                button.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "ScreenOS")
            }
            button.imagePosition = .imageLeft
            button.action = #selector(menuBarClicked)
            button.target = self
        }

        updateMenu()
    }

    @objc private func menuBarClicked() {
        updateMenu()
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Show Desktop (this works!)
        let showItem = menu.addItem(withTitle: "Show Desktop", action: #selector(toggleShowDesktop), keyEquivalent: "")
        showItem.target = self

        menu.addItem(.separator())

        // Tiling
        let tileMenu = NSMenu()
        tileMenu.addItem(withTitle: "Izquierda", action: #selector(tileLeft), keyEquivalent: "").target = self
        tileMenu.addItem(withTitle: "Derecha", action: #selector(tileRight), keyEquivalent: "").target = self
        tileMenu.addItem(withTitle: "Arriba", action: #selector(tileTop), keyEquivalent: "").target = self
        tileMenu.addItem(withTitle: "Abajo", action: #selector(tileBottom), keyEquivalent: "").target = self

        let tileMenuItem = NSMenuItem(title: "Tiling", action: nil, keyEquivalent: "")
        tileMenuItem.submenu = tileMenu
        menu.addItem(tileMenuItem)

        menu.addItem(.separator())

        let quitItem = menu.addItem(withTitle: "Salir", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self

        statusItem.menu = menu
    }

    private var isShowingDesktop = false
    private var hiddenApps: [NSRunningApplication] = []

    @objc private func toggleShowDesktop() {
        if isShowingDesktop {
            for app in hiddenApps {
                app.unhide()
            }
            hiddenApps = []
            isShowingDesktop = false
        } else {
            let apps = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier && !$0.isHidden
            }
            hiddenApps = []
            for app in apps {
                app.hide()
                hiddenApps.append(app)
            }
            isShowingDesktop = true
        }
    }

    @objc private func tileLeft() {
        applyTiling(position: "left")
    }
    @objc private func tileRight() {
        applyTiling(position: "right")
    }
    @objc private func tileTop() {
        // "bottom" position in applyTiling actually puts window at visual top
        applyTiling(position: "bottom")
    }
    @objc private func tileBottom() {
        // "top" position in applyTiling actually puts window at visual bottom
        applyTiling(position: "top")
    }

    private func applyTiling(position: String) {
        guard AXIsProcessTrusted() else {
            let alert = NSAlert()
            alert.messageText = "Permission Required"
            alert.informativeText = "Accessibility permission is required for Tiling. Please enable it in System Settings."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
            return
        }

        // Get system-wide accessibility element
        let systemWide = AXUIElementCreateSystemWide()

        // Get focused application
        var focusedAppValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let focusedApp = focusedAppValue,
              CFGetTypeID(focusedApp) == AXUIElementGetTypeID()
        else {
            NSSound.beep()
            return
        }

        let axApp = focusedApp as! AXUIElement

        // Get focused window
        var focusedWindowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowValue) == .success,
              let focusedWindow = focusedWindowValue,
              CFGetTypeID(focusedWindow) == AXUIElementGetTypeID()
        else {
            NSSound.beep()
            return
        }

        let axWindow = focusedWindow as! AXUIElement

        // Calculate new frame
        let screen = NSScreen.main ?? NSScreen()
        let screenFrame = screen.visibleFrame

        var newFrame: CGRect
        switch position {
        case "left":
            newFrame = CGRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: screenFrame.width / 2, height: screenFrame.height)
        case "right":
            newFrame = CGRect(x: screenFrame.origin.x + screenFrame.width / 2, y: screenFrame.origin.y, width: screenFrame.width / 2, height: screenFrame.height)
        case "top":
            newFrame = CGRect(x: screenFrame.origin.x, y: screenFrame.origin.y + screenFrame.height / 2, width: screenFrame.width, height: screenFrame.height / 2)
        case "bottom":
            newFrame = CGRect(x: screenFrame.origin.x, y: screenFrame.origin.y, width: screenFrame.width, height: screenFrame.height / 2)
        default:
            return
        }

        // Set position and size
        var point = CGPoint(x: newFrame.origin.x, y: newFrame.origin.y)
        var size = CGSize(width: newFrame.width, height: newFrame.height)

        if let pointValue = AXValueCreate(.cgPoint, &point),
           let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWindow, kAXPositionAttribute as CFString, pointValue)
            AXUIElementSetAttributeValue(axWindow, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    @objc private func quitApp() {
        for app in hiddenApps {
            app.unhide()
        }
        NSApp.terminate(nil)
    }
}

// Keep a strong reference to the delegate
var appDelegate: AppDelegate!

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()