import Foundation

public enum Resolution: String, Codable, CaseIterable {
    case hd = "720P"
    case fullHD = "1080P"
    case twoK = "2K"
    case fourK = "4K"

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .hd: return (1280, 720)
        case .fullHD: return (1920, 1080)
        case .twoK: return (2560, 1440)
        case .fourK: return (3840, 2160)
        }
    }

    var width: Int { dimensions.width }
    var height: Int { dimensions.height }

    var displayName: String {
        switch self {
        case .hd: return "720P"
        case .fullHD: return "1080P"
        case .twoK: return "2K"
        case .fourK: return "4K"
        }
    }
}
