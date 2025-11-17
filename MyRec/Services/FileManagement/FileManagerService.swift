import Foundation
import AVFoundation
import CoreGraphics
import OSLog

/// Handles file system operations for recordings
/// Manages file naming, validation, metadata extraction, and cleanup
class FileManagerService {

    // MARK: - Types

    enum FileError: LocalizedError {
        case invalidPath(String)
        case directoryCreationFailed(Error)
        case fileNotFound(URL)
        case fileOperationFailed(Error)
        case metadataExtractionFailed(Error)
        case pathNotWritable(String)

        var errorDescription: String? {
            switch self {
            case .invalidPath(let path):
                return "Invalid file path: \(path)"
            case .directoryCreationFailed(let error):
                return "Failed to create directory: \(error.localizedDescription)"
            case .fileNotFound(let url):
                return "File not found: \(url.path)"
            case .fileOperationFailed(let error):
                return "File operation failed: \(error.localizedDescription)"
            case .metadataExtractionFailed(let error):
                return "Failed to extract video metadata: \(error.localizedDescription)"
            case .pathNotWritable(let path):
                return "Path is not writable: \(path)"
            }
        }
    }

    // MARK: - Properties

    private let settingsManager: SettingsManager
    private let logger = Logger(subsystem: "com.myrec.app", category: "FileManagerService")

    // MARK: - Initialization

    init(settingsManager: SettingsManager = SettingsManager.shared) {
        self.settingsManager = settingsManager
    }

    // MARK: - URL Generation

    /// Generate a unique recording URL with timestamp
    /// - Parameter timestamp: The recording start time
    /// - Returns: URL for the recording file
    func generateRecordingURL(timestamp: Date = Date()) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let timestampString = dateFormatter.string(from: timestamp)

        let filename = "REC-\(timestampString).mp4"

        return getSaveLocationURL().appendingPathComponent(filename)
    }

    /// Generate a URL for a trimmed version of a recording
    /// - Parameter originalURL: The original recording URL
    /// - Returns: URL for the trimmed recording
    func generateTrimmedURL(from originalURL: URL) -> URL {
        let originalFilename = originalURL.deletingPathExtension().lastPathComponent
        let trimmedFilename = "\(originalFilename)-trimmed.mp4"

        return originalURL.deletingLastPathComponent().appendingPathComponent(trimmedFilename)
    }

    // MARK: - Directory Management

    /// Ensure the recording directory exists and is writable
    /// - Throws: FileError if directory cannot be created or is not writable
    func ensureRecordingDirectoryExists() throws {
        let saveLocationURL = getSaveLocationURL()
        let path = saveLocationURL.path

        // Check if directory exists
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)

        if exists {
            // Verify it's a directory
            guard isDirectory.boolValue else {
                throw FileError.invalidPath("Save location is not a directory: \(path)")
            }

            // Verify writable
            guard isPathWritable(path) else {
                throw FileError.pathNotWritable(path)
            }

            logger.debug("Recording directory verified: \(path)")
        } else {
            // Create directory
            do {
                try FileManager.default.createDirectory(
                    at: saveLocationURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                logger.info("Created recording directory: \(path)")
            } catch {
                throw FileError.directoryCreationFailed(error)
            }
        }
    }

    // MARK: - File Operations

    /// Move a recording from temporary location to final location
    /// - Parameters:
    ///   - tempURL: The temporary file URL
    ///   - finalURL: The final destination URL
    /// - Returns: The final URL where the file was moved
    /// - Throws: FileError if move operation fails
    func saveRecording(from tempURL: URL, to finalURL: URL) throws -> URL {
        logger.info("Saving recording: \(tempURL.lastPathComponent) → \(finalURL.lastPathComponent)")

        // Verify temp file exists
        guard FileManager.default.fileExists(atPath: tempURL.path) else {
            throw FileError.fileNotFound(tempURL)
        }

        do {
            // Remove existing file at destination if it exists
            if FileManager.default.fileExists(atPath: finalURL.path) {
                try FileManager.default.removeItem(at: finalURL)
                logger.debug("Removed existing file at destination")
            }

            // Ensure destination directory exists
            let destinationDirectory = finalURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Move file
            try FileManager.default.moveItem(at: tempURL, to: finalURL)

            logger.info("Recording saved successfully: \(finalURL.path)")

            return finalURL
        } catch {
            throw FileError.fileOperationFailed(error)
        }
    }

    /// Delete a recording file
    /// - Parameter url: The URL of the file to delete
    /// - Throws: FileError if deletion fails
    func deleteRecording(at url: URL) throws {
        logger.info("Deleting recording: \(url.lastPathComponent)")

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound(url)
        }

        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Recording deleted successfully")
        } catch {
            throw FileError.fileOperationFailed(error)
        }
    }

    /// Copy a recording to a new location
    /// - Parameters:
    ///   - sourceURL: The source file URL
    ///   - destinationURL: The destination file URL
    /// - Returns: The destination URL
    /// - Throws: FileError if copy operation fails
    func copyRecording(from sourceURL: URL, to destinationURL: URL) throws -> URL {
        logger.info("Copying recording: \(sourceURL.lastPathComponent) → \(destinationURL.lastPathComponent)")

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw FileError.fileNotFound(sourceURL)
        }

        do {
            // Remove existing file at destination if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            // Ensure destination directory exists
            let destinationDirectory = destinationURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Copy file
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            logger.info("Recording copied successfully")

            return destinationURL
        } catch {
            throw FileError.fileOperationFailed(error)
        }
    }

    // MARK: - Metadata Extraction

    /// Extract video metadata from a recording file
    /// - Parameter url: The recording file URL
    /// - Returns: VideoMetadata struct with file information
    /// - Throws: FileError if metadata extraction fails
    func getVideoMetadata(for url: URL) async throws -> VideoMetadata {
        logger.debug("Extracting metadata for: \(url.lastPathComponent)")

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw FileError.fileNotFound(url)
        }

        do {
            let asset = AVAsset(url: url)

            // Load asset properties
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)

            guard let videoTrack = tracks.first(where: { $0.mediaType == .video }) else {
                throw FileError.metadataExtractionFailed(
                    NSError(domain: "FileManagerService", code: -1,
                           userInfo: [NSLocalizedDescriptionKey: "No video track found"])
                )
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)

            // Get file attributes
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let createdAt = attributes[.creationDate] as? Date ?? Date()

            // Determine format from file extension
            let format = url.pathExtension.uppercased() + "/H.264"

            let metadata = VideoMetadata(
                filename: url.lastPathComponent,
                fileURL: url,
                fileSize: fileSize,
                duration: duration.seconds,
                resolution: naturalSize,
                frameRate: Int(nominalFrameRate),
                createdAt: createdAt,
                format: format
            )

            logger.debug("Metadata extracted: \(metadata.resolutionString), \(metadata.durationString)")

            return metadata
        } catch {
            throw FileError.metadataExtractionFailed(error)
        }
    }

    // MARK: - Validation

    /// Validate that a save location path is valid and writable
    /// - Parameter path: The path to validate
    /// - Returns: true if path is valid and writable
    func validateSaveLocation(_ path: String) -> Bool {
        // Check if path is not empty
        guard !path.isEmpty else {
            logger.warning("Save location path is empty")
            return false
        }

        // Expand tilde and resolve path
        let expandedPath = (path as NSString).expandingTildeInPath

        // Check if directory exists or can be created
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory)

        if exists {
            // Must be a directory and writable
            return isDirectory.boolValue && isPathWritable(expandedPath)
        } else {
            // Check if parent directory exists and is writable
            let parentPath = (expandedPath as NSString).deletingLastPathComponent
            var parentIsDirectory: ObjCBool = false
            let parentExists = FileManager.default.fileExists(atPath: parentPath, isDirectory: &parentIsDirectory)

            return parentExists && parentIsDirectory.boolValue && isPathWritable(parentPath)
        }
    }

    /// Check if a path is writable
    /// - Parameter path: The path to check
    /// - Returns: true if path is writable
    func isPathWritable(_ path: String) -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath
        return FileManager.default.isWritableFile(atPath: expandedPath)
    }

    /// Calculate the total file size for a recording
    /// - Parameter url: The recording file URL
    /// - Returns: File size in bytes, or 0 if file doesn't exist
    func calculateFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            logger.error("Failed to calculate file size: \(error.localizedDescription)")
            return 0
        }
    }

    /// List all recordings in the save directory
    /// - Returns: Array of URLs for all MP4 files in the save directory
    func listRecordings() throws -> [URL] {
        let saveLocationURL = getSaveLocationURL()

        guard FileManager.default.fileExists(atPath: saveLocationURL.path) else {
            return []
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: saveLocationURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for MP4 files starting with REC-
            let recordings = contents.filter { url in
                url.pathExtension.lowercased() == "mp4" &&
                url.lastPathComponent.hasPrefix("REC-")
            }

            // Sort by creation date (newest first)
            return recordings.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
        } catch {
            throw FileError.fileOperationFailed(error)
        }
    }

    // MARK: - Private Helpers

    private func getSaveLocationURL() -> URL {
        return settingsManager.savePath
    }
}
