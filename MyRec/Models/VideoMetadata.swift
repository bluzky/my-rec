import Foundation
import SwiftUI
import AppKit

/// Metadata for a recorded video file
struct VideoMetadata: Identifiable, Equatable {
    // MARK: - Properties
    let id = UUID()
    let filename: String
    let fileURL: URL
    let duration: Double
    let resolution: Resolution
    let frameRate: FrameRate
    let fileSize: Int64
    let createdDate: Date
    let thumbnail: NSImage?
    /// Actual pixel size extracted from the video track (not rounded to presets)
    let naturalSize: CGSize

    // MARK: - Computed Properties

    /// Formatted duration string (e.g., "00:01:23")
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Formatted file size string (e.g., "15.2 MB")
    var formattedFileSize: String {
        let mb = Double(fileSize) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", Double(fileSize) / 1_024.0)
        }
    }

    /// Resolution display string (e.g., "1920×1080 @ 30 FPS")
    var displayResolution: String {
        "\(resolution.width)×\(resolution.height) @ \(frameRate.value) FPS"
    }

    /// Creation date string (e.g., "Nov 18, 2025 at 2:30 PM")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }

    /// Time ago string (e.g., "2 hours ago")
    var timeAgo: String {
        let now = Date()
        let interval = now.timeIntervalSince(createdDate)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else {
            let days = Int(interval / 86400)
            return days == 1 ? "Yesterday" : "\(days) days ago"
        }
    }

    /// Whether the file is likely large (over 100MB)
    var isLargeFile: Bool {
        return fileSize > 100 * 1_048_576 // 100MB
    }

    /// Color for thumbnail based on file size (for UI display)
    var thumbnailColor: Color {
        if fileSize > 500 * 1_048_576 { // > 500MB
            return .red
        } else if fileSize > 100 * 1_048_576 { // > 100MB
            return .orange
        } else {
            return .blue
        }
    }

    /// Aspect ratio derived from the video's natural size (fallbacks to nominal resolution)
    var aspectRatio: CGFloat {
        guard naturalSize.height > 0 else {
            return CGFloat(resolution.width) / CGFloat(resolution.height)
        }
        return naturalSize.width / naturalSize.height
    }

    // MARK: - Initialization

    init(
        filename: String,
        fileURL: URL,
        duration: Double,
        resolution: Resolution,
        frameRate: FrameRate,
        fileSize: Int64,
        createdDate: Date,
        thumbnail: NSImage? = nil,
        naturalSize: CGSize? = nil
    ) {
        self.filename = filename
        self.fileURL = fileURL
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.fileSize = fileSize
        self.createdDate = createdDate
        self.thumbnail = thumbnail
        // Use real track size when available; otherwise fallback to nominal resolution
        self.naturalSize = naturalSize ?? CGSize(width: resolution.width, height: resolution.height)
    }

    // MARK: - Equatable

    static func == (lhs: VideoMetadata, rhs: VideoMetadata) -> Bool {
        return lhs.fileURL == rhs.fileURL
    }

    // MARK: - Convenience Methods

    /// Create mock metadata for testing
    static func mock(
        filename: String = "MyRecord-20251118143022.mp4",
        duration: Double = 30.0,
        resolution: Resolution = .fullHD,
        frameRate: FrameRate = .fps30,
        fileSize: Int64 = 150_000_000,
        createdDate: Date = Date()
    ) -> VideoMetadata {
        let fileURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
            .appendingPathComponent(filename)

        return VideoMetadata(
            filename: filename,
            fileURL: fileURL,
            duration: duration,
            resolution: resolution,
            frameRate: frameRate,
            fileSize: fileSize,
            createdDate: createdDate,
            thumbnail: nil
        )
    }

    // MARK: - Legacy Properties (for backward compatibility)

    var createdAt: Date { createdDate }
    var fileSizeString: String { formattedFileSize }
    var durationString: String { formattedDuration }
    var resolutionString: String { "\(resolution.width)×\(resolution.height)" }
    var createdAtString: String { formattedDate }
}
