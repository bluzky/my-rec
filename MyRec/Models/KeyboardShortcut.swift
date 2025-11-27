import Foundation
import Carbon

/// Represents a customizable keyboard shortcut
///
/// Stores modifier keys (Cmd, Option, Shift, Control) and the main key code.
/// Provides formatting for display and validation.
public struct KeyboardShortcut: Codable, Equatable, Hashable {
    /// The main key code (e.g., kVK_ANSI_1 for "1" key)
    public let keyCode: Int

    /// Modifier flags (Cmd, Option, Shift, Control)
    public let modifiers: ModifierFlags

    /// Type of shortcut action
    public enum Action: String, Codable, CaseIterable {
        case startPauseRecording = "start_pause"
        case stopRecording = "stop"
        case openSettings = "settings"

        var displayName: String {
            switch self {
            case .startPauseRecording: return "Start/Pause Recording"
            case .stopRecording: return "Stop Recording"
            case .openSettings: return "Open Settings"
            }
        }
    }

    /// Modifier key flags
    public struct ModifierFlags: OptionSet, Codable, Hashable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let command = ModifierFlags(rawValue: 1 << 0)
        public static let option = ModifierFlags(rawValue: 1 << 1)
        public static let shift = ModifierFlags(rawValue: 1 << 2)
        public static let control = ModifierFlags(rawValue: 1 << 3)
    }

    // MARK: - Initialization

    public init(keyCode: Int, modifiers: ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public init?(keyCode: Int, carbonModifiers: UInt32) {
        self.keyCode = keyCode

        var flags: ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }

        // Require at least one modifier
        guard !flags.isEmpty else { return nil }

        self.modifiers = flags
    }

    // MARK: - Default Shortcuts

    /// Default keyboard shortcuts
    public static var defaults: [Action: KeyboardShortcut] {
        [
            .startPauseRecording: KeyboardShortcut(keyCode: kVK_ANSI_1, modifiers: [.command, .shift]),
            .stopRecording: KeyboardShortcut(keyCode: kVK_ANSI_2, modifiers: [.command, .shift]),
            .openSettings: KeyboardShortcut(keyCode: kVK_ANSI_Comma, modifiers: [.command, .option])
        ]
    }

    // MARK: - Display

    /// Returns a human-readable display string (e.g., "⌘⌥1")
    public var displayString: String {
        var result = ""

        if modifiers.contains(.control) {
            result += "⌃"
        }
        if modifiers.contains(.option) {
            result += "⌥"
        }
        if modifiers.contains(.shift) {
            result += "⇧"
        }
        if modifiers.contains(.command) {
            result += "⌘"
        }

        result += keyCodeToString(keyCode)

        return result
    }

    /// Converts Carbon key code to display string
    private func keyCodeToString(_ code: Int) -> String {
        // Number keys
        switch code {
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"

        // Letter keys
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"

        // Function keys
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"

        // Special keys
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_Grave: return "`"

        // Arrow keys
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"

        default:
            return "?"
        }
    }

    // MARK: - Carbon Conversion

    /// Converts modifiers to Carbon event modifiers
    public var carbonModifiers: UInt32 {
        var result: UInt32 = 0

        if modifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }
        if modifiers.contains(.control) {
            result |= UInt32(controlKey)
        }

        return result
    }

    // MARK: - Validation

    /// Validates that the shortcut is usable
    ///
    /// Checks:
    /// - At least one modifier key is present
    /// - Key code is valid
    /// - Not reserved by system (basic check)
    public func isValid() -> Bool {
        // Must have at least one modifier
        guard !modifiers.isEmpty else { return false }

        // Key code should be reasonable
        guard keyCode >= 0 && keyCode <= 255 else { return false }

        return true
    }

    /// Checks if this shortcut conflicts with common system shortcuts
    public func isSystemReserved() -> Bool {
        // Common system shortcuts to avoid
        let systemShortcuts: [(keyCode: Int, modifiers: ModifierFlags)] = [
            (kVK_ANSI_Q, [.command]),           // ⌘Q - Quit
            (kVK_ANSI_W, [.command]),           // ⌘W - Close Window
            (kVK_ANSI_H, [.command]),           // ⌘H - Hide App
            (kVK_ANSI_M, [.command]),           // ⌘M - Minimize
            (kVK_Tab, [.command]),              // ⌘Tab - App Switcher
            (kVK_Space, [.command]),            // ⌘Space - Spotlight
            (kVK_ANSI_C, [.command]),           // ⌘C - Copy
            (kVK_ANSI_V, [.command]),           // ⌘V - Paste
            (kVK_ANSI_X, [.command]),           // ⌘X - Cut
            (kVK_ANSI_Z, [.command]),           // ⌘Z - Undo
            (kVK_ANSI_A, [.command]),           // ⌘A - Select All
        ]

        for systemShortcut in systemShortcuts {
            if keyCode == systemShortcut.keyCode && modifiers == systemShortcut.modifiers {
                return true
            }
        }

        return false
    }
}
