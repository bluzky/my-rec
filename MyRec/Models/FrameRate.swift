import Foundation

public enum FrameRate: Int, Codable, CaseIterable {
    case fps15 = 15
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60

    var value: Int { self.rawValue }

    var displayName: String {
        "\(value) FPS"
    }
}
