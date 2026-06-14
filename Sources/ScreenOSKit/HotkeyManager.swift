import Carbon
import Cocoa

/// Manages global hotkeys using the Carbon RegisterEventHotKey API.
///
/// Carbon is the most reliable way to register global hotkeys without
/// Accessibility permission for key interception.
public final class HotkeyManager {

    public static let shared = HotkeyManager()

    // MARK: - Callbacks

    public var onShowDesktop: (() -> Void)?
    public var onTileLeft: (() -> Void)?
    public var onTileRight: (() -> Void)?
    public var onTileTop: (() -> Void)?
    public var onTileBottom: (() -> Void)?
    public var onTileTopLeft: (() -> Void)?
    public var onTileTopRight: (() -> Void)?
    public var onTileBottomLeft: (() -> Void)?
    public var onTileBottomRight: (() -> Void)?
    public var onCenter: (() -> Void)?
    public var onMaximize: (() -> Void)?
    public var onSwitcher: (() -> Void)?

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var hotKeyIDs: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {}

    // MARK: - Registration

    /// Registers the built-in default hotkeys.
    public func registerDefaults() {
        register(keyCode: kVK_ANSI_D, modifiers: cmdKey + shiftKey) { [weak self] in
            self?.onShowDesktop?()
        }
        register(keyCode: kVK_LeftArrow, modifiers: cmdKey + optionKey) { [weak self] in
            self?.onTileLeft?()
        }
        register(keyCode: kVK_RightArrow, modifiers: cmdKey + optionKey) { [weak self] in
            self?.onTileRight?()
        }
        register(keyCode: kVK_UpArrow, modifiers: cmdKey + optionKey) { [weak self] in
            self?.onTileTop?()
        }
        register(keyCode: kVK_DownArrow, modifiers: cmdKey + optionKey) { [weak self] in
            self?.onTileBottom?()
        }
        register(keyCode: kVK_ANSI_M, modifiers: cmdKey + optionKey) { [weak self] in
            self?.onMaximize?()
        }
        register(keyCode: kVK_ANSI_C, modifiers: cmdKey + optionKey) { [weak self] in
            self?.onCenter?()
        }
        register(keyCode: kVK_ANSI_Grave, modifiers: cmdKey) { [weak self] in
            self?.onSwitcher?()
        }
    }

    /// Registers hotkeys, preferring any user-saved shortcuts from UserDefaults,
    /// falling back to the built-in defaults for each unset action.
    public func registerWithSavedShortcuts() {
        unregisterAll()

        let defaults = UserDefaults.standard

        func registerAction(key: String, defaultKeyCode: Int, defaultMods: Int, callback: @escaping () -> Void) {
            if let data = defaults.data(forKey: key),
               let saved = try? JSONDecoder().decode(ShortcutRecorder.Shortcut.self, from: data) {
                register(keyCode: Int(saved.keyCode), modifiers: Int(saved.flags), action: callback)
            } else {
                register(keyCode: defaultKeyCode, modifiers: defaultMods, action: callback)
            }
        }

        registerAction(key: "hotkey-showDesktop", defaultKeyCode: kVK_ANSI_D,     defaultMods: cmdKey + shiftKey)  { [weak self] in self?.onShowDesktop?() }
        registerAction(key: "hotkey-tileLeft",    defaultKeyCode: kVK_LeftArrow,   defaultMods: cmdKey + optionKey) { [weak self] in self?.onTileLeft?() }
        registerAction(key: "hotkey-tileRight",   defaultKeyCode: kVK_RightArrow,  defaultMods: cmdKey + optionKey) { [weak self] in self?.onTileRight?() }
        registerAction(key: "hotkey-tileTop",     defaultKeyCode: kVK_UpArrow,     defaultMods: cmdKey + optionKey) { [weak self] in self?.onTileTop?() }
        registerAction(key: "hotkey-tileBottom",  defaultKeyCode: kVK_DownArrow,   defaultMods: cmdKey + optionKey) { [weak self] in self?.onTileBottom?() }
        registerAction(key: "hotkey-maximize",    defaultKeyCode: kVK_ANSI_M,      defaultMods: cmdKey + optionKey) { [weak self] in self?.onMaximize?() }
        registerAction(key: "hotkey-center",      defaultKeyCode: kVK_ANSI_C,      defaultMods: cmdKey + optionKey) { [weak self] in self?.onCenter?() }
        registerAction(key: "hotkey-switcher",    defaultKeyCode: kVK_ANSI_Grave,  defaultMods: cmdKey)             { [weak self] in self?.onSwitcher?() }
    }

    /// Registers a single hotkey.
    @discardableResult
    public func register(keyCode: Int, modifiers: Int, action: @escaping () -> Void) -> Bool {
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
            return false
        }

        hotKeyRefs.append(hotKeyRef)
        hotKeyIDs[UInt32(id)] = action

        if eventHandler == nil {
            installEventHandler()
        }

        return true
    }

    /// Unregisters all hotkeys and removes the event handler.
    public func unregisterAll() {
        for ref in hotKeyRefs {
            if let ref = ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        hotKeyIDs.removeAll()
        nextID = 1

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
                if let action = manager.hotKeyIDs[hotKeyID.id] {
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
