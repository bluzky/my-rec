import Cocoa
import Carbon

/// Manages global keyboard shortcuts for MyRec
///
/// Provides global hotkey registration using Carbon Event Manager API.
/// Requires accessibility permission for system-wide keyboard event monitoring.
///
/// Supports customizable shortcuts loaded from SettingsManager.
class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    // MARK: - Properties

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?
    private var shortcutMapping: [UInt32: KeyboardShortcut.Action] = [:]

    /// Notification names for keyboard shortcuts
    struct Notifications {
        static let startRecording = Notification.Name("KeyboardShortcut.StartRecording")
        static let stopRecording = Notification.Name("KeyboardShortcut.StopRecording")
        static let openSettings = Notification.Name("KeyboardShortcut.OpenSettings")
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Hotkey Registration

    /// Registers keyboard shortcuts from SettingsManager
    ///
    /// Loads custom shortcuts and registers them with the system.
    /// - Parameter shortcuts: Dictionary of shortcuts to register
    /// - Returns: True if all shortcuts registered successfully, false otherwise
    @discardableResult
    func registerShortcuts(_ shortcuts: [KeyboardShortcut.Action: KeyboardShortcut]) -> Bool {
        // Clear existing shortcuts first
        unregisterAllShortcuts()

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: OSType(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let error = GetEventParameter(
                event,
                OSType(kEventParamDirectObject),
                OSType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard error == noErr else { return error }

            KeyboardShortcutManager.shared.handleHotKey(id: hotKeyID.id)
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Register individual hotkeys
        var hotKeyID: UInt32 = 1
        for (action, shortcut) in shortcuts {
            var hotKeyRef: EventHotKeyRef?
            let eventHotKeyID = EventHotKeyID(signature: OSType(0x4D524543), id: hotKeyID) // 'MREC'

            let status = RegisterEventHotKey(
                UInt32(shortcut.keyCode),
                shortcut.carbonModifiers,
                eventHotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                hotKeyRefs.append(hotKeyRef)
                shortcutMapping[hotKeyID] = action
                hotKeyID += 1
            } else {
                print("⚠️ Failed to register shortcut for \(action.displayName)")
            }
        }

        return !hotKeyRefs.isEmpty
    }

    /// Registers default keyboard shortcuts
    ///
    /// Convenience method that loads defaults and registers them.
    /// - Returns: True if all shortcuts registered successfully, false otherwise
    @discardableResult
    func registerDefaultShortcuts() -> Bool {
        return registerShortcuts(KeyboardShortcut.defaults)
    }

    /// Unregisters all keyboard shortcuts
    func unregisterAllShortcuts() {
        for hotKeyRef in hotKeyRefs {
            if let ref = hotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
        shortcutMapping.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    // MARK: - Event Handling

    /// Handles hotkey press events
    ///
    /// Posts appropriate notification based on hotkey ID.
    /// - Parameter id: The hotkey ID that was pressed
    private func handleHotKey(id: UInt32) {
        guard let action = shortcutMapping[id] else {
            print("⚠️ Unknown hotkey ID: \(id)")
            return
        }

        let notification: Notification.Name

        switch action {
        case .startPauseRecording:
            notification = Notifications.startRecording
        case .stopRecording:
            notification = Notifications.stopRecording
        case .openSettings:
            notification = Notifications.openSettings
        }

        NotificationCenter.default.post(name: notification, object: nil)
    }

    // MARK: - Cleanup

    deinit {
        unregisterAllShortcuts()
    }
}
