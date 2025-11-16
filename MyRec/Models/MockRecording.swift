//
//  MockRecording.swift
//  MyRec
//
//  Mock data model for UI development and testing
//

import Foundation
import SwiftUI

/// Mock recording data for UI development without actual video files
struct MockRecording: Identifiable, Hashable {
    let id: UUID
    let filename: String
    let duration: TimeInterval
    let resolution: Resolution
    let frameRate: FrameRate
    let fileSize: Int64 // bytes
    let createdDate: Date
    let thumbnailColor: Color // Placeholder color for video preview

    init(
        id: UUID = UUID(),
        filename: String,
        duration: TimeInterval,
        resolution: Resolution,
        frameRate: FrameRate,
        fileSize: Int64,
        createdDate: Date,
        thumbnailColor: Color = .blue
    ) {
        self.id = id
        self.filename = filename
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.fileSize = fileSize
        self.createdDate = createdDate
        self.thumbnailColor = thumbnailColor
    }

    /// Formatted duration string (HH:MM:SS)
    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Formatted file size string (MB or GB)
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Formatted date string (relative or absolute)
    var dateString: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(createdDate) {
            return "Today"
        } else if calendar.isDateInYesterday(createdDate) {
            return "Yesterday"
        } else if let days = calendar.dateComponents([.day], from: createdDate, to: now).day, days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: createdDate)
        }
    }

    /// Full date and time string
    var fullDateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }

    /// Metadata summary string
    var metadataString: String {
        "\(resolution.width)×\(resolution.height) @ \(frameRate.value) FPS · \(durationString) · \(fileSizeString)"
    }
}

/// Generates mock recording data for UI testing
class MockRecordingGenerator {

    private static let resolutions: [Resolution] = [.hd, .fullHD, .twoK, .fourK]
    private static let frameRates: [FrameRate] = [.fps15, .fps24, .fps30, .fps60]
    private static let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .red, .cyan]

    /// Generate a random mock recording
    static func randomRecording(daysAgo: Int = 0) -> MockRecording {
        let resolution = resolutions.randomElement() ?? .fullHD
        let frameRate = frameRates.randomElement() ?? .fps30
        let duration = TimeInterval.random(in: 30...3600) // 30 seconds to 1 hour
        let fileSize = calculateFileSize(resolution: resolution, frameRate: frameRate, duration: duration)
        let color = colors.randomElement() ?? .blue

        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        let randomSeconds = Int.random(in: 0...86400) // Random time within the day
        let createdDate = date.addingTimeInterval(TimeInterval(-randomSeconds))

        let timestamp = dateFormatter.string(from: createdDate)
        let filename = "REC-\(timestamp).mp4"

        return MockRecording(
            filename: filename,
            duration: duration,
            resolution: resolution,
            frameRate: frameRate,
            fileSize: fileSize,
            createdDate: createdDate,
            thumbnailColor: color
        )
    }

    /// Generate multiple mock recordings
    static func generate(count: Int) -> [MockRecording] {
        var recordings: [MockRecording] = []

        // Distribute recordings across different days
        for i in 0..<count {
            let daysAgo = i / 3 // ~3 recordings per day
            recordings.append(randomRecording(daysAgo: daysAgo))
        }

        // Sort by date (newest first)
        return recordings.sorted { $0.createdDate > $1.createdDate }
    }

    /// Generate recordings for specific date range
    static func generate(from startDate: Date, to endDate: Date, count: Int) -> [MockRecording] {
        var recordings: [MockRecording] = []
        let timeInterval = endDate.timeIntervalSince(startDate)

        for _ in 0..<count {
            let randomOffset = TimeInterval.random(in: 0...timeInterval)
            let createdDate = startDate.addingTimeInterval(randomOffset)

            let resolution = resolutions.randomElement() ?? .fullHD
            let frameRate = frameRates.randomElement() ?? .fps30
            let duration = TimeInterval.random(in: 30...3600)
            let fileSize = calculateFileSize(resolution: resolution, frameRate: frameRate, duration: duration)
            let color = colors.randomElement() ?? .blue

            let timestamp = dateFormatter.string(from: createdDate)
            let filename = "REC-\(timestamp).mp4"

            recordings.append(MockRecording(
                filename: filename,
                duration: duration,
                resolution: resolution,
                frameRate: frameRate,
                fileSize: fileSize,
                createdDate: createdDate,
                thumbnailColor: color
            ))
        }

        return recordings.sorted { $0.createdDate > $1.createdDate }
    }

    /// Calculate approximate file size based on recording parameters
    /// Uses rough estimates: 720p@30fps = 2.5 Mbps, 1080p@30fps = 5 Mbps, etc.
    private static func calculateFileSize(resolution: Resolution, frameRate: FrameRate, duration: TimeInterval) -> Int64 {
        // Base bitrate for 1080p @ 30fps (5 Mbps)
        let baseBitrate: Double = 5_000_000 // bits per second

        // Scale by resolution (pixels)
        let resolutionScale = Double(resolution.width * resolution.height) / Double(1920 * 1080)

        // Scale by frame rate
        let frameRateScale = Double(frameRate.value) / 30.0

        // Calculate bitrate
        let bitrate = baseBitrate * resolutionScale * frameRateScale

        // Calculate file size in bytes
        let fileSizeBytes = Int64((bitrate / 8) * duration)

        // Add some randomness (±10%)
        let randomFactor = Double.random(in: 0.9...1.1)

        return Int64(Double(fileSizeBytes) * randomFactor)
    }

    /// Shared date formatter for consistent filename timestamps
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        return formatter
    }()
}

// MARK: - Sample Data for Previews

extension MockRecording {

    /// Sample recording for SwiftUI previews
    static let sample = MockRecording(
        filename: "REC-20251116103045.mp4",
        duration: 332, // 5:32
        resolution: .fullHD,
        frameRate: .fps30,
        fileSize: 142_300_000, // ~142 MB
        createdDate: Date(),
        thumbnailColor: .blue
    )

    /// Sample recordings array for SwiftUI previews
    static let samples = MockRecordingGenerator.generate(count: 10)
}
