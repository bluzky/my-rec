import Cocoa
import Carbon

/// Manages global keyboard shortcuts for MyRec
///
/// Provides global hotkey registration using Carbon Event Manager API.
/// Requires accessibility permission for system-wide keyboard event monitoring.
///
/// Default shortcuts:
/// - ⌘⌥1: Start/Pause recording
/// - ⌘⌥2: Stop recording
/// - ⌘⌥,: Open settings
class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()

    // MARK: - Properties

    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandler: EventHandlerRef?

    /// Notification names for keyboard shortcuts
    struct Notifications {
        static let startRecording = Notification.Name("KeyboardShortcut.StartRecording")
        static let stopRecording = Notification.Name("KeyboardShortcut.StopRecording")
        static let openSettings = Notification.Name("KeyboardShortcut.OpenSettings")
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Permission Checking

    /// Checks if accessibility permission is granted
    ///
    /// Accessibility permission is required for global keyboard event monitoring.
    /// - Returns: True if permission is granted, false otherwise
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Requests accessibility permission from the user
    ///
    /// Shows system prompt if permission is not granted.
    /// User must manually enable in System Settings → Privacy & Security → Accessibility.
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - Hotkey Registration

    /// Registers all default keyboard shortcuts
    ///
    /// Default shortcuts:
    /// - ⌘⌥1 (Cmd+Opt+1): Start/Pause recording
    /// - ⌘⌥2 (Cmd+Opt+2): Stop recording
    /// - ⌘⌥, (Cmd+Opt+Comma): Open settings
    ///
    /// - Returns: True if all shortcuts registered successfully, false otherwise
    @discardableResult
    func registerDefaultShortcuts() -> Bool {
        guard checkAccessibilityPermission() else {
            return false
        }

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
        let shortcuts: [(keyCode: Int, id: UInt32, notification: Notification.Name)] = [
            (kVK_ANSI_1, 1, Notifications.startRecording),      // ⌘⌥1
            (kVK_ANSI_2, 2, Notifications.stopRecording),       // ⌘⌥2
            (kVK_ANSI_Comma, 3, Notifications.openSettings)     // ⌘⌥,
        ]

        for shortcut in shortcuts {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x4D524543), id: shortcut.id) // 'MREC'

            let modifiers = UInt32(cmdKey | optionKey)

            let status = RegisterEventHotKey(
                UInt32(shortcut.keyCode),
                modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if status == noErr {
                hotKeyRefs.append(hotKeyRef)
            } else {
                return false
            }
        }

        return true
    }

    /// Unregisters all keyboard shortcuts
    func unregisterAllShortcuts() {
        for hotKeyRef in hotKeyRefs {
            if let ref = hotKeyRef {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()

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
        let notification: Notification.Name

        switch id {
        case 1:
            notification = Notifications.startRecording
        case 2:
            notification = Notifications.stopRecording
        case 3:
            notification = Notifications.openSettings
        default:
            return
        }

        NotificationCenter.default.post(name: notification, object: nil)
    }

    // MARK: - Cleanup

    deinit {
        unregisterAllShortcuts()
    }
}
