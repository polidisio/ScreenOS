import AppKit
import ApplicationServices
import ScreenOSKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var preferencesWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
        setupHotkeys()
        checkAccessibilityPermission()
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        let hm = HotkeyManager.shared
        hm.onShowDesktop     = { [weak self] in self?.toggleShowDesktop() }
        hm.onTileLeft        = { TilingEngine.shared.applyPosition(.left) }
        hm.onTileRight       = { TilingEngine.shared.applyPosition(.right) }
        hm.onTileTop         = { TilingEngine.shared.applyPosition(.top) }
        hm.onTileBottom      = { TilingEngine.shared.applyPosition(.bottom) }
        hm.onTileTopLeft     = { TilingEngine.shared.applyPosition(.topLeft) }
        hm.onTileTopRight    = { TilingEngine.shared.applyPosition(.topRight) }
        hm.onTileBottomLeft  = { TilingEngine.shared.applyPosition(.bottomLeft) }
        hm.onTileBottomRight = { TilingEngine.shared.applyPosition(.bottomRight) }
        hm.onMaximize        = { TilingEngine.shared.applyPosition(.maximize) }
        hm.onCenter          = { TilingEngine.shared.applyPosition(.center) }
        hm.onSwitcher        = { SwitcherController.shared.show() }
        // Applies user-saved shortcuts from Preferences, falling back to built-in defaults
        hm.registerWithSavedShortcuts()
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Use bundled icon, then fall back to an SF Symbol
            let icon = NSImage(named: "AppIcon")
                ?? NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "ScreenOS")
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.imagePosition = .imageOnly
            button.action = #selector(menuBarClicked)
            button.target = self
            button.toolTip = "ScreenOS"
        }

        updateMenu()
    }

    @objc private func menuBarClicked() {
        updateMenu()
        statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func updateMenu() {
        let menu = NSMenu()

        // Show Desktop — label flips to "Show Windows" when desktop is visible
        let sdTitle = ShowDesktopManager.shared.isActive ? "Show Windows" : "Show Desktop"
        let showItem = menu.addItem(withTitle: sdTitle, action: #selector(toggleShowDesktop), keyEquivalent: "")
        showItem.target = self
        showItem.keyEquivalentModifierMask = [.command, .shift]
        showItem.keyEquivalent = "d"

        menu.addItem(.separator())

        // Tiling submenu
        let tileMenu = NSMenu()
        let tiles: [(String, Selector, String, NSEvent.ModifierFlags)] = [
            ("Left",         #selector(tileLeft),        "←", [.command, .option]),
            ("Right",        #selector(tileRight),       "→", [.command, .option]),
            ("Top",          #selector(tileTop),         "↑", [.command, .option]),
            ("Bottom",       #selector(tileBottom),      "↓", [.command, .option]),
            ("Top-Left",     #selector(tileTopLeft),     "",  []),
            ("Top-Right",    #selector(tileTopRight),    "",  []),
            ("Bottom-Left",  #selector(tileBottomLeft),  "",  []),
            ("Bottom-Right", #selector(tileBottomRight), "",  []),
            ("Maximize",     #selector(tileMaximize),    "m", [.command, .option]),
            ("Center",       #selector(tileCenter),      "c", [.command, .option]),
        ]
        for (title, action, key, mods) in tiles {
            let item = tileMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = mods
            item.target = self
        }
        let tileItem = NSMenuItem(title: "Tiling", action: nil, keyEquivalent: "")
        tileItem.submenu = tileMenu
        menu.addItem(tileItem)

        menu.addItem(.separator())

        let switcherItem = menu.addItem(withTitle: "Window Switcher", action: #selector(showSwitcher), keyEquivalent: "`")
        switcherItem.keyEquivalentModifierMask = .command
        switcherItem.target = self

        menu.addItem(.separator())

        let prefsItem = menu.addItem(withTitle: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.keyEquivalentModifierMask = .command
        prefsItem.target = self

        menu.addItem(.separator())

        let quitItem = menu.addItem(withTitle: "Quit ScreenOS", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self

        statusItem.menu = menu
    }

    // MARK: - Permissions

    private func checkAccessibilityPermission() {
        guard !PermissionsManager.shared.hasAccessibilityPermission else { return }

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "ScreenOS needs Accessibility permission to move and resize windows.\n\nGo to: System Settings → Privacy & Security → Accessibility → Add ScreenOS"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            PermissionsManager.shared.requestAccessibilityPermission()
        }
    }

    // MARK: - Actions

    @objc private func toggleShowDesktop() {
        ShowDesktopManager.shared.toggle()
        // Refresh menu label to reflect new state
        updateMenu()
    }

    @objc private func tileLeft()        { TilingEngine.shared.applyPosition(.left) }
    @objc private func tileRight()       { TilingEngine.shared.applyPosition(.right) }
    @objc private func tileTop()         { TilingEngine.shared.applyPosition(.top) }
    @objc private func tileBottom()      { TilingEngine.shared.applyPosition(.bottom) }
    @objc private func tileTopLeft()     { TilingEngine.shared.applyPosition(.topLeft) }
    @objc private func tileTopRight()    { TilingEngine.shared.applyPosition(.topRight) }
    @objc private func tileBottomLeft()  { TilingEngine.shared.applyPosition(.bottomLeft) }
    @objc private func tileBottomRight() { TilingEngine.shared.applyPosition(.bottomRight) }
    @objc private func tileMaximize()    { TilingEngine.shared.applyPosition(.maximize) }
    @objc private func tileCenter()      { TilingEngine.shared.applyPosition(.center) }

    @objc private func showSwitcher() {
        SwitcherController.shared.show()
    }

    @objc private func openPreferences() {
        if preferencesWindowController == nil {
            let vc = PreferencesViewController()
            let window = NSWindow(contentViewController: vc)
            window.title = "ScreenOS Preferences"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 520, height: 460))
            window.center()
            window.isReleasedWhenClosed = false
            preferencesWindowController = NSWindowController(window: window)
        }
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        HotkeyManager.shared.unregisterAll()
        NSApp.terminate(nil)
    }
}

// MARK: - Entry point

var appDelegate: AppDelegate!
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
