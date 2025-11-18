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
    /// - Parameter tempURL: Temporary video file URL
    /// - Returns: VideoMetadata with file information
    func saveVideoFile(from tempURL: URL) async throws -> VideoMetadata {
        print("📁 FileManagerService: Starting file save process...")
        print("  Source: \(tempURL.path)")
        print("  Destination: \(saveDirectory.path)")

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

        // Extract metadata
        let metadata = try await extractMetadata(from: finalURL)
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
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestamp = dateFormatter.string(from: Date())

        let filename = "REC-\(timestamp).mp4"
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
    /// - Parameter url: Video file URL
    /// - Returns: VideoMetadata with extracted information
    private func extractMetadata(from url: URL) async throws -> VideoMetadata {
        let asset = AVAsset(url: url)

        // Load asset properties
        try await asset.loadValues(forKeys: ["duration", "tracks"])

        // Check if asset is readable
        let status = asset.statusOfValue(forKey: "duration", error: nil)
        guard status == .loaded else {
            throw FileError.metadataExtractionFailed
        }

        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let createdDate = attributes[.creationDate] as? Date ?? Date()

        // Extract video properties
        var videoTracks = [AVAssetTrack]()
        if let tracks = try? await asset.loadTracks(withMediaType: .video) {
            videoTracks = tracks
        }

        var resolution: Resolution = .fullHD // Default
        var frameRate: FrameRate = .fps30 // Default

        if let videoTrack = videoTracks.first {
            // Get natural size
            let naturalSize = try await videoTrack.load(.naturalSize)
            let width = Int(naturalSize.width)
            let height = Int(naturalSize.height)

            // Find matching resolution or use closest
            resolution = Resolution.allCases.min { res1, res2 in
                let diff1 = abs(res1.width - width) + abs(res1.height - height)
                let diff2 = abs(res2.width - width) + abs(res2.height - height)
                return diff1 < diff2
            } ?? .fullHD

            // Get nominal frame rate
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
            frameRate = FrameRate.allCases.min { abs($0.value - Int(nominalFrameRate)) < abs($1.value - Int(nominalFrameRate)) } ?? .fps30
        }

        // Get duration in seconds
        let duration = asset.duration.seconds

        return VideoMetadata(
            filename: url.lastPathComponent,
            fileURL: url,
            duration: duration,
            resolution: resolution,
            frameRate: frameRate,
            fileSize: fileSize,
            createdDate: createdDate
        )
    }

    /// Open Finder to show file
    /// - Parameter url: File to show in Finder
    private func showFileInFinder(_ url: URL) async {
        // Switch to main thread for NSWorkspace
        await MainActor.run {
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