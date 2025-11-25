import Foundation
import AVFoundation
import AppKit

/// Manages video file operations, metadata extraction, and final file storage
class FileManagerService {
    static let shared = FileManagerService()

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let settingsManager = SettingsManager.shared

    // MARK: - Computed Properties

    /// Current save directory from settings (supports user configuration)
    private var saveDirectory: URL {
        settingsManager.savePath
    }

    // MARK: - Initialization
    private init() {
        // Initialization complete - save directory is dynamic from SettingsManager
    }

    // MARK: - Public Interface

    /// Move a temporary video file to final location with metadata extraction
    /// - Parameters:
    ///   - tempURL: Temporary video file URL
    ///   - resolution: Actual resolution used during recording
    ///   - frameRate: Actual frame rate used during recording
    /// - Returns: VideoMetadata with file information
    func saveVideoFile(from tempURL: URL, resolution: Resolution, frameRate: FrameRate) async throws -> VideoMetadata {
        print("📁 FileManagerService: Starting file save process...")
        print("  Source: \(tempURL.path)")
        print("  Destination: \(saveDirectory.path)")
        print("  📊 Received metadata - Resolution: \(resolution.displayName), Frame Rate: \(frameRate.displayName)")

        // Verify temp file exists and has content
        guard fileManager.fileExists(atPath: tempURL.path) else {
            throw FileError.sourceFileNotFound
        }

        let sourceSize = try fileManager.attributesOfItem(atPath: tempURL.path)[.size] as? Int64 ?? 0
        guard sourceSize > 0 else {
            throw FileError.sourceFileCorrupted
        }

        print("✅ Source file verified - Size: \(formatFileSize(sourceSize))")

        // Generate unique filename
        let finalURL = generateUniqueFilename()
        print("📝 Generated filename: \(finalURL.lastPathComponent)")

        // Ensure save directory exists
        try ensureDirectoryExists(saveDirectory)
        print("📁 Save directory ready: \(saveDirectory.path)")

        // Move file atomically
        try moveFile(from: tempURL, to: finalURL)
        print("✅ File moved successfully to: \(finalURL.path)")

        // Extract metadata with actual recording settings
        let metadata = try await extractMetadata(from: finalURL, resolution: resolution, frameRate: frameRate)
        print("✅ Metadata extracted - Duration: \(String(format: "%.1f", metadata.duration))s, Size: \(formatFileSize(metadata.fileSize))")

        // Open Finder to show the file
        await showFileInFinder(finalURL)
        print("🗂 Finder opened to show saved file")

        return metadata
    }

    /// Delete temporary file
    /// - Parameter url: File to delete
    func cleanupTempFile(_ url: URL) {
        do {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
                print("🗑 Temp file cleaned up: \(url.lastPathComponent)")
            }
        } catch {
            print("⚠️ Warning: Failed to cleanup temp file: \(error)")
        }
    }

    /// Get list of saved recordings from configured save directory
    /// - Returns: Array of VideoMetadata for all .mp4 files
    func getSavedRecordings() async throws -> [VideoMetadata] {
        print("📂 FileManagerService: Scanning for saved recordings...")
        print("  Location: \(saveDirectory.path)")

        let files = try fileManager.contentsOfDirectory(
            at: saveDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )

        let mp4Files = files.filter { $0.pathExtension.lowercased() == "mp4" }
        print("📂 Found \(mp4Files.count) MP4 files")

        var recordings: [VideoMetadata] = []
        for file in mp4Files {
            do {
                let metadata = try await extractMetadata(from: file)
                recordings.append(metadata)
            } catch {
                print("⚠️ Warning: Failed to extract metadata from \(file.lastPathComponent): \(error)")
            }
        }

        // Sort by creation date (newest first)
        recordings.sort { $0.createdDate > $1.createdDate }
        print("✅ Loaded \(recordings.count) recordings")

        return recordings
    }

    // MARK: - Private Methods

    /// Generate unique filename with timestamp
    /// - Returns: Final file URL in configured save directory
    private func generateUniqueFilename() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let filename = "MyRecording-\(timestamp).mp4"
        return saveDirectory.appendingPathComponent(filename)
    }

    /// Ensure directory exists, create if missing
    /// - Parameter url: Directory URL to ensure exists
    private func ensureDirectoryExists(_ url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("📁 Created directory: \(url.path)")
        }
    }

    /// Move file atomically with error handling
    /// - Parameters:
    ///   - source: Source file URL
    ///   - destination: Destination file URL
    private func moveFile(from source: URL, to destination: URL) throws {
        // Remove destination if it exists (shouldn't happen with unique timestamps)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
            print("⚠️ Removed existing file: \(destination.lastPathComponent)")
        }

        // Move file atomically
        try fileManager.moveItem(at: source, to: destination)
    }

    /// Extract metadata from video file using AVAsset
    /// - Parameters:
    ///   - url: Video file URL
    ///   - resolution: Optional resolution used during recording (if nil, will extract from file)
    ///   - frameRate: Optional frame rate used during recording (if nil, will extract from file)
    /// - Returns: VideoMetadata with extracted information
    private func extractMetadata(from url: URL, resolution: Resolution? = nil, frameRate: FrameRate? = nil) async throws -> VideoMetadata {
        print("📊 extractMetadata - Received resolution: \(resolution?.displayName ?? "nil"), frameRate: \(frameRate?.displayName ?? "nil")")
        let asset = AVURLAsset(url: url)

        // Load asset properties and verify they loaded successfully
        _ = try await asset.load(.duration, .tracks)

        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let createdDate = attributes[.creationDate] as? Date ?? Date()

        // Extract video properties
        var videoTracks = [AVAssetTrack]()
        if let tracks = try? await asset.loadTracks(withMediaType: .video) {
            videoTracks = tracks
        }

        // Use provided resolution and frame rate, or extract from file if not provided
        var finalResolution: Resolution = resolution ?? .fullHD
        var finalFrameRate: FrameRate = frameRate ?? .fps30
        var naturalSize = CGSize(width: finalResolution.width, height: finalResolution.height)

        if let videoTrack = videoTracks.first {
            // Get natural size (always extract actual dimensions)
            let rawSize = try await videoTrack.load(.naturalSize)
            let transform = try await videoTrack.load(.preferredTransform)
            let transformedSize = rawSize.applying(transform)
            naturalSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))

            // Only extract resolution and frame rate if not provided
            if resolution == nil {
                let width = Int(naturalSize.width.rounded())
                let height = Int(naturalSize.height.rounded())

                // Find matching resolution or use closest
                if let closestResolution = Resolution.allCases.min(by: { res1, res2 in
                    let diff1 = abs(res1.width - width) + abs(res1.height - height)
                    let diff2 = abs(res2.width - width) + abs(res2.height - height)
                    return diff1 < diff2
                }) {
                    finalResolution = closestResolution
                }
            }

            if frameRate == nil {
                // Get nominal frame rate
                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                if let closestFrameRate = FrameRate.allCases.min(by: { abs($0.value - Int(nominalFrameRate)) < abs($1.value - Int(nominalFrameRate)) }) {
                    finalFrameRate = closestFrameRate
                }
            }
        }

        // Get duration in seconds using new API
        let duration = try await asset.load(.duration).seconds

        print("📊 extractMetadata - Final values - Resolution: \(finalResolution.displayName), Frame Rate: \(finalFrameRate.displayName)")

        // Generate thumbnail asynchronously
        // TODO: Implement ThumbnailGenerator class
        // let thumbnailGenerator = ThumbnailGenerator.shared
        // let thumbnail = await thumbnailGenerator.generateThumbnail(
        //     from: url,
        //     at: CMTime(seconds: min(1.0, duration / 2), preferredTimescale: 600), // Use 1 second or middle of video
        //     size: CGSize(width: 320, height: 180)
        // )
        let thumbnail: NSImage? = nil

        return VideoMetadata(
            filename: url.lastPathComponent,
            fileURL: url,
            duration: duration,
            resolution: finalResolution,
            frameRate: finalFrameRate,
            fileSize: fileSize,
            createdDate: createdDate,
            thumbnail: thumbnail,
            naturalSize: naturalSize
        )
    }

    /// Open Finder to show file
    /// - Parameter url: File to show in Finder
    private func showFileInFinder(_ url: URL) async {
        // Switch to main thread for NSWorkspace
        _ = await MainActor.run {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
    }

    /// Format file size for human readable display
    /// - Parameter bytes: File size in bytes
    /// - Returns: Formatted string
    private func formatFileSize(_ bytes: Int64) -> String {
        let mb = Double(bytes) / 1_048_576.0
        if mb >= 1.0 {
            return String(format: "%.1f MB", mb)
        } else {
            return String(format: "%.0f KB", Double(bytes) / 1_024.0)
        }
    }
}

// MARK: - Errors

enum FileError: LocalizedError {
    case sourceFileNotFound
    case sourceFileCorrupted
    case destinationFileExists
    case metadataExtractionFailed
    case directoryCreationFailed

    var errorDescription: String? {
        switch self {
        case .sourceFileNotFound:
            return "Source video file not found"
        case .sourceFileCorrupted:
            return "Source video file is corrupted or empty"
        case .destinationFileExists:
            return "Destination file already exists"
        case .metadataExtractionFailed:
            return "Failed to extract video metadata"
        case .directoryCreationFailed:
            return "Failed to create destination directory"
        }
    }
}
