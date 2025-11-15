import Foundation
import CoreGraphics

struct VideoMetadata {
    let filename: String
    let fileURL: URL
    let fileSize: Int64
    let duration: TimeInterval
    let resolution: CGSize
    let frameRate: Int
    let createdAt: Date
    let format: String

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var resolutionString: String {
        "\(Int(resolution.width)) × \(Int(resolution.height))"
    }

    var createdAtString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
}
