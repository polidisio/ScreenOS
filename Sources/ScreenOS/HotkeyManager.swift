import Carbon
import Cocoa

/// Manages global hotkeys using the Carbon RegisterEventHotKey API.
///
/// Note: This uses the older Carbon API because it's the most reliable way
/// to register global hotkeys on macOS without needing Accessibility permission
/// for key interception.
final class HotkeyManager {

    static let shared = HotkeyManager()

    // Callbacks for each action
    var onShowDesktop: (() -> Void)?
    var onTileLeft: (() -> Void)?
    var onTileRight: (() -> Void)?
    var onTileTop: (() -> Void)?
    var onTileBottom: (() -> Void)?
    var onTileTopLeft: (() -> Void)?
    var onTileTopRight: (() -> Void)?
    var onTileBottomLeft: (() -> Void)?
    var onTileBottomRight: (() -> Void)?
    var onCenter: (() -> Void)?
    var onMaximize: (() -> Void)?
    var onSwitcher: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var hotKeyIDs: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    private var eventHandler: EventHandlerRef?

    private init() {}

    /// Registers all default hotkeys.
    func registerDefaults() {
        // Show Desktop: Cmd+Shift+D
        register(keyCode: kVK_ANSI_D, modifiers: cmdKey + shiftKey, action: { [weak self] in
            self?.onShowDesktop?()
        })

        // Tile Left: Cmd+Opt+Left
        register(keyCode: kVK_LeftArrow, modifiers: cmdKey + optionKey, action: { [weak self] in
            self?.onTileLeft?()
        })

        // Tile Right: Cmd+Opt+Right
        register(keyCode: kVK_RightArrow, modifiers: cmdKey + optionKey, action: { [weak self] in
            self?.onTileRight?()
        })

        // Tile Top: Cmd+Opt+Up
        register(keyCode: kVK_UpArrow, modifiers: cmdKey + optionKey, action: { [weak self] in
            self?.onTileTop?()
        })

        // Tile Bottom: Cmd+Opt+Down
        register(keyCode: kVK_DownArrow, modifiers: cmdKey + optionKey, action: { [weak self] in
            self?.onTileBottom?()
        })

        // Maximize: Cmd+Opt+M
        register(keyCode: kVK_ANSI_M, modifiers: cmdKey + optionKey, action: { [weak self] in
            self?.onMaximize?()
        })

        // Center: Cmd+Opt+C
        register(keyCode: kVK_ANSI_C, modifiers: cmdKey + optionKey, action: { [weak self] in
            self?.onCenter?()
        })

        // Switcher: Cmd+`
        register(keyCode: kVK_ANSI_Grave, modifiers: cmdKey, action: { [weak self] in
            self?.onSwitcher?()
        })
    }

    /// Registers a single hotkey.
    /// - Parameters:
    ///   - keyCode: Virtual key code (kVK_ constants from Carbon)
    ///   - modifiers: Modifier flags (cmdKey, optionKey, shiftKey, controlKey)
    ///   - action: Closure to call when hotkey is pressed
    @discardableResult
    func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x534F534B), id: UInt32(id))

        let status = RegisterEventHotKey(
            UInt32(keyCode),
            UInt32(modifiers),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

guard status == noErr else {
            print("[HotkeyManager] Failed to register hotkey \(keyCode): \(status)")
            return false
        }

        hotKeyRefs.append(hotKeyRef)
        hotKeyIDs[UInt32(id)] = action

        if eventHandler == nil {
            installEventHandler()
        }

        return true
    }

    /// Unregisters all hotkeys.
    func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        hotKeyIDs.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregisterAll()
    }

    // MARK: - Private

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, inEvent, userData -> OSStatus in
            guard let userData = userData else { return noErr }

            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                inEvent,
                UInt32(kEventParamDirectObject),
                UInt32(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if err == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                let keyID = hotKeyID.id
                if let action = manager.hotKeyIDs[keyID] {
                    action()
                }
            }

            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }
}
