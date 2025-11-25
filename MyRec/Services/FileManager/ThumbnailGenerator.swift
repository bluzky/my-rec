import Foundation
import AVFoundation
import AppKit

/// Generates video thumbnails from recorded files
class ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    // MARK: - Configuration
    private let thumbnailSize = CGSize(width: 320, height: 180)
    private let captureTime = CMTime.zero // First frame
    private let batchSize = 5 // Process 5 thumbnails concurrently per batch

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Interface

    /// Generate thumbnail from video file at first frame
    /// - Parameter url: Video file URL
    /// - Returns: NSImage thumbnail or nil if generation fails
    func generateThumbnail(from url: URL) async -> NSImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)

        // Configure generator for optimal quality
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = thumbnailSize
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero

        // Generate thumbnail at first frame
        do {
            let (cgImage, _) = try await generator.image(at: captureTime)
            return NSImage(cgImage: cgImage, size: thumbnailSize)
        } catch {
            // Silently fail - return nil for missing thumbnails
            return nil
        }
    }

    /// Generate thumbnails for multiple videos in batches
    /// Processes videos in groups to avoid overwhelming the system
    /// - Parameter urls: Array of video file URLs
    /// - Returns: Dictionary mapping URLs to generated thumbnails
    func generateThumbnails(for urls: [URL]) async -> [URL: NSImage?] {
        var results: [URL: NSImage?] = [:]

        // Process URLs in batches
        let batches = stride(from: 0, to: urls.count, by: batchSize).map {
            Array(urls[$0..<min($0 + batchSize, urls.count)])
        }

        for batch in batches {
            // Process each batch concurrently
            let batchResults = await withTaskGroup(of: (URL, NSImage?).self) { group in
                for url in batch {
                    group.addTask {
                        let thumbnail = await self.generateThumbnail(from: url)
                        return (url, thumbnail)
                    }
                }

                var batchMap: [URL: NSImage?] = [:]
                for await (url, thumbnail) in group {
                    batchMap[url] = thumbnail
                }
                return batchMap
            }

            // Merge batch results into final results
            results.merge(batchResults) { _, new in new }
        }

        return results
    }

    /// Generate thumbnail for a single video metadata object
    /// - Parameter metadata: VideoMetadata to generate thumbnail for
    /// - Returns: Updated VideoMetadata with thumbnail
    func generateThumbnail(for metadata: VideoMetadata) async -> VideoMetadata {
        guard let thumbnail = await generateThumbnail(from: metadata.fileURL) else {
            return metadata
        }

        // Return new metadata with thumbnail
        return VideoMetadata(
            filename: metadata.filename,
            fileURL: metadata.fileURL,
            duration: metadata.duration,
            resolution: metadata.resolution,
            frameRate: metadata.frameRate,
            fileSize: metadata.fileSize,
            createdDate: metadata.createdDate,
            thumbnail: thumbnail,
            naturalSize: metadata.naturalSize
        )
    }
}
