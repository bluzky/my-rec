import Combine
import Foundation

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

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

    private enum Keys {
        static let savePath = "savePath"
        static let defaultResolution = "defaultResolution"
        static let defaultFrameRate = "defaultFrameRate"
        static let launchAtLogin = "launchAtLogin"
        static let defaultSettings = "defaultSettings"
    }

    private init() {
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

        if let settingsData = UserDefaults.standard.data(forKey: Keys.defaultSettings),
           let settings = try? JSONDecoder().decode(RecordingSettings.self, from: settingsData) {
            self.defaultSettings = settings
        } else {
            self.defaultSettings = .default
        }
    }

    func save() {
        UserDefaults.standard.set(savePath, forKey: Keys.savePath)
        UserDefaults.standard.set(defaultResolution.rawValue, forKey: Keys.defaultResolution)
        UserDefaults.standard.set(defaultFrameRate.rawValue, forKey: Keys.defaultFrameRate)
        UserDefaults.standard.set(launchAtLogin, forKey: Keys.launchAtLogin)

        if let settingsData = try? JSONEncoder().encode(defaultSettings) {
            UserDefaults.standard.set(settingsData, forKey: Keys.defaultSettings)
        }
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
        defaultSettings = .default
    }
}
