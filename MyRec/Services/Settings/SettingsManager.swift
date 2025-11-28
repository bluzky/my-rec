import Combine
import Foundation

public class SettingsManager: ObservableObject {
    public static let shared = SettingsManager()

    @Published var savePath: URL {
        didSet { save() }
    }

    @Published var defaultResolution: Resolution {
        didSet { save() }
    }

    @Published var defaultFrameRate: FrameRate {
        didSet { save() }
    }

    @Published var launchAtLogin: Bool {
        didSet { save() }
    }

    @Published var defaultSettings: RecordingSettings {
        didSet { save() }
    }

    @Published var hideDockIcon: Bool {
        didSet { save() }
    }

    @Published var rememberLastManualRegion: Bool {
        didSet { save() }
    }

    @Published var keyboardShortcuts: [KeyboardShortcut.Action: KeyboardShortcut] {
        didSet { save() }
    }

    private enum Keys {
        static let savePath = "savePath"
        static let defaultResolution = "defaultResolution"
        static let defaultFrameRate = "defaultFrameRate"
        static let launchAtLogin = "launchAtLogin"
        static let defaultSettings = "defaultSettings"
        static let hideDockIcon = "hideDockIcon"
        static let keyboardShortcuts = "keyboardShortcuts"
        static let rememberLastManualRegion = "rememberLastManualRegion"
    }

    public init() {
        let defaultPath = FileManager.default.urls(
            for: .moviesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        self.savePath = UserDefaults.standard.url(forKey: Keys.savePath) ?? defaultPath

        if let resolutionRaw = UserDefaults.standard.string(forKey: Keys.defaultResolution),
           let resolution = Resolution(rawValue: resolutionRaw) {
            self.defaultResolution = resolution
        } else {
            self.defaultResolution = .fullHD
        }

        self.defaultFrameRate = FrameRate(
            rawValue: UserDefaults.standard.integer(forKey: Keys.defaultFrameRate)
        ) ?? .fps30

        self.launchAtLogin = UserDefaults.standard.bool(forKey: Keys.launchAtLogin)

        // Default to true (hide dock icon) for new users
        if UserDefaults.standard.object(forKey: Keys.hideDockIcon) == nil {
            self.hideDockIcon = true
        } else {
            self.hideDockIcon = UserDefaults.standard.bool(forKey: Keys.hideDockIcon)
        }

        if let settingsData = UserDefaults.standard.data(forKey: Keys.defaultSettings),
           let settings = try? JSONDecoder().decode(RecordingSettings.self, from: settingsData) {
            self.defaultSettings = settings
        } else {
            self.defaultSettings = .default
        }

        // Remember last manual region toggle - default to false
        if UserDefaults.standard.object(forKey: Keys.rememberLastManualRegion) == nil {
            self.rememberLastManualRegion = false
        } else {
            self.rememberLastManualRegion = UserDefaults.standard.bool(forKey: Keys.rememberLastManualRegion)
        }

        // Load keyboard shortcuts
        if let shortcutsData = UserDefaults.standard.data(forKey: Keys.keyboardShortcuts),
           let shortcuts = try? JSONDecoder().decode([KeyboardShortcut.Action: KeyboardShortcut].self, from: shortcutsData) {
            self.keyboardShortcuts = shortcuts
        } else {
            self.keyboardShortcuts = KeyboardShortcut.defaults
        }
    }

    func save() {
        UserDefaults.standard.set(savePath, forKey: Keys.savePath)
        UserDefaults.standard.set(defaultResolution.rawValue, forKey: Keys.defaultResolution)
        UserDefaults.standard.set(defaultFrameRate.rawValue, forKey: Keys.defaultFrameRate)
        UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)
        UserDefaults.standard.set(hideDockIcon, forKey: Keys.hideDockIcon)

        if let settingsData = try? JSONEncoder().encode(defaultSettings) {
            UserDefaults.standard.set(settingsData, forKey: Keys.defaultSettings)
        }

        if let shortcutsData = try? JSONEncoder().encode(keyboardShortcuts) {
            UserDefaults.standard.set(shortcutsData, forKey: Keys.keyboardShortcuts)
        }

        UserDefaults.standard.set(rememberLastManualRegion, forKey: Keys.rememberLastManualRegion)
    }

    func reset() {
        let defaultPath = FileManager.default.urls(
            for: .moviesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        savePath = defaultPath
        defaultResolution = .fullHD
        defaultFrameRate = .fps30
        launchAtLogin = false
        hideDockIcon = true
        defaultSettings = .default
        keyboardShortcuts = KeyboardShortcut.defaults
        rememberLastManualRegion = false
    }
}
