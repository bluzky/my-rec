//
//  FileManagerServiceTests.swift
//  MyRecTests
//
//  Created by Week 5 Backend Integration - Day 22
//

import XCTest
@testable import MyRec
#if canImport(MyRecCore)
@testable import MyRecCore
#endif
import AVFoundation

final class FileManagerServiceTests: XCTestCase {
    var service: FileManagerService!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        // Create temp directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerServiceTests_\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )

        // Create service with custom settings
        let settingsManager = SettingsManager.shared
        settingsManager.savePath = tempDirectory

        service = FileManagerService(settingsManager: settingsManager)
    }

    override func tearDown() {
        service = nil

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        super.tearDown()
    }

    // MARK: - URL Generation Tests

    func testGenerateRecordingURL() {
        // When
        let url = service.generateRecordingURL()

        // Then
        XCTAssertTrue(url.path.starts(with: tempDirectory.path), "URL should be in temp directory")
        XCTAssertTrue(url.lastPathComponent.starts(with: "REC-"), "Filename should start with REC-")
        XCTAssertTrue(url.lastPathComponent.hasSuffix(".mp4"), "Filename should end with .mp4")
        XCTAssertEqual(url.lastPathComponent.count, 22, "Filename length should be 22 (REC-14digits.mp4)")
    }

    func testGenerateRecordingURLWithCustomTimestamp() {
        // Given
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"

        let timestamp = dateFormatter.date(from: "20251117143022")!

        // When
        let url = service.generateRecordingURL(timestamp: timestamp)

        // Then
        XCTAssertEqual(url.lastPathComponent, "REC-20251117143022.mp4")
    }

    func testGenerateTrimmedURL() {
        // Given
        let originalURL = tempDirectory.appendingPathComponent("REC-20251117143022.mp4")

        // When
        let trimmedURL = service.generateTrimmedURL(from: originalURL)

        // Then
        XCTAssertEqual(trimmedURL.lastPathComponent, "REC-20251117143022-trimmed.mp4")
        XCTAssertEqual(trimmedURL.deletingLastPathComponent().path, originalURL.deletingLastPathComponent().path)
    }

    // MARK: - Directory Management Tests

    func testEnsureRecordingDirectoryExists() throws {
        // Given - directory already exists from setUp
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDirectory.path))

        // When/Then - should not throw
        try service.ensureRecordingDirectoryExists()
        XCTAssertTrue(true, "Should verify existing directory without error")
    }

    func testEnsureRecordingDirectoryCreatesNew() throws {
        // Given - use a new subdirectory that doesn't exist
        let newDirectory = tempDirectory.appendingPathComponent("new_recordings")
        SettingsManager.shared.savePath = newDirectory
        service = FileManagerService(settingsManager: SettingsManager.shared)

        // When
        try service.ensureRecordingDirectoryExists()

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: newDirectory.path))

        // Cleanup
        try? FileManager.default.removeItem(at: newDirectory)
    }

    // MARK: - File Operations Tests

    func testSaveRecording() throws {
        // Given - create a temp file
        let tempURL = tempDirectory.appendingPathComponent("temp.mp4")
        let testData = "test video data".data(using: .utf8)!
        try testData.write(to: tempURL)

        let finalURL = tempDirectory.appendingPathComponent("REC-20251117143022.mp4")

        // When
        let savedURL = try service.saveRecording(from: tempURL, to: finalURL)

        // Then
        XCTAssertEqual(savedURL, finalURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempURL.path), "Temp file should be moved")

        // Verify content
        let savedData = try Data(contentsOf: finalURL)
        XCTAssertEqual(savedData, testData)
    }

    func testSaveRecordingOverwritesExisting() throws {
        // Given - create existing file
        let finalURL = tempDirectory.appendingPathComponent("REC-20251117143022.mp4")
        let oldData = "old data".data(using: .utf8)!
        try oldData.write(to: finalURL)

        // And new temp file
        let tempURL = tempDirectory.appendingPathComponent("temp.mp4")
        let newData = "new data".data(using: .utf8)!
        try newData.write(to: tempURL)

        // When
        _ = try service.saveRecording(from: tempURL, to: finalURL)

        // Then - old file should be replaced
        let savedData = try Data(contentsOf: finalURL)
        XCTAssertEqual(savedData, newData)
    }

    func testSaveRecordingWithMissingSourceThrowsError() {
        // Given
        let tempURL = tempDirectory.appendingPathComponent("nonexistent.mp4")
        let finalURL = tempDirectory.appendingPathComponent("REC-20251117143022.mp4")

        // When/Then
        XCTAssertThrowsError(try service.saveRecording(from: tempURL, to: finalURL)) { error in
            XCTAssertTrue(error is FileManagerService.FileError)
        }
    }

    func testDeleteRecording() throws {
        // Given - create a file
        let url = tempDirectory.appendingPathComponent("REC-20251117143022.mp4")
        let testData = "test".data(using: .utf8)!
        try testData.write(to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        // When
        try service.deleteRecording(at: url)

        // Then
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDeleteNonexistentRecordingThrowsError() {
        // Given
        let url = tempDirectory.appendingPathComponent("nonexistent.mp4")

        // When/Then
        XCTAssertThrowsError(try service.deleteRecording(at: url)) { error in
            XCTAssertTrue(error is FileManagerService.FileError)
        }
    }

    func testCopyRecording() throws {
        // Given - create source file
        let sourceURL = tempDirectory.appendingPathComponent("source.mp4")
        let testData = "test video data".data(using: .utf8)!
        try testData.write(to: sourceURL)

        let destinationURL = tempDirectory.appendingPathComponent("destination.mp4")

        // When
        let copiedURL = try service.copyRecording(from: sourceURL, to: destinationURL)

        // Then
        XCTAssertEqual(copiedURL, destinationURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), "Source should still exist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path), "Destination should exist")

        // Verify content
        let copiedData = try Data(contentsOf: destinationURL)
        XCTAssertEqual(copiedData, testData)
    }

    // MARK: - Validation Tests

    func testValidateSaveLocation() {
        // Given - valid path that exists
        let validPath = tempDirectory.path
        XCTAssertTrue(service.validateSaveLocation(validPath))

        // Given - empty path
        XCTAssertFalse(service.validateSaveLocation(""))

        // Given - path that can be created (parent exists)
        let newPath = tempDirectory.appendingPathComponent("new_folder").path
        XCTAssertTrue(service.validateSaveLocation(newPath))

        // Given - completely invalid path
        XCTAssertFalse(service.validateSaveLocation("/nonexistent/invalid/path/that/cannot/be/created"))
    }

    func testIsPathWritable() {
        // Given - writable path
        let writablePath = tempDirectory.path
        XCTAssertTrue(service.isPathWritable(writablePath))

        // Given - non-writable path (root directory)
        XCTAssertFalse(service.isPathWritable("/System/Library"))
    }

    func testCalculateFileSize() throws {
        // Given - create a file with known size
        let url = tempDirectory.appendingPathComponent("test.mp4")
        let testData = Data(repeating: 0xFF, count: 1024) // 1 KB
        try testData.write(to: url)

        // When
        let fileSize = service.calculateFileSize(at: url)

        // Then
        XCTAssertEqual(fileSize, 1024)
    }

    func testCalculateFileSizeForNonexistentFile() {
        // Given
        let url = tempDirectory.appendingPathComponent("nonexistent.mp4")

        // When
        let fileSize = service.calculateFileSize(at: url)

        // Then
        XCTAssertEqual(fileSize, 0, "Should return 0 for nonexistent file")
    }

    // MARK: - List Recordings Tests

    func testListRecordingsReturnsEmpty() throws {
        // Given - empty directory
        let recordings = try service.listRecordings()

        // Then
        XCTAssertTrue(recordings.isEmpty)
    }

    func testListRecordingsReturnsMP4Files() throws {
        // Given - create some recording files
        let urls = [
            tempDirectory.appendingPathComponent("REC-20251117143022.mp4"),
            tempDirectory.appendingPathComponent("REC-20251117143023.mp4"),
            tempDirectory.appendingPathComponent("REC-20251117143024.mp4")
        ]

        for url in urls {
            let data = "test".data(using: .utf8)!
            try data.write(to: url)
        }

        // When
        let recordings = try service.listRecordings()

        // Then
        XCTAssertEqual(recordings.count, 3)
        XCTAssertTrue(recordings.allSatisfy { $0.pathExtension == "mp4" })
        XCTAssertTrue(recordings.allSatisfy { $0.lastPathComponent.starts(with: "REC-") })
    }

    func testListRecordingsFiltersNonRecordings() throws {
        // Given - create mix of files
        let recordings = [
            tempDirectory.appendingPathComponent("REC-20251117143022.mp4"),
            tempDirectory.appendingPathComponent("REC-20251117143023.mp4")
        ]

        let nonRecordings = [
            tempDirectory.appendingPathComponent("other.mp4"),
            tempDirectory.appendingPathComponent("REC-20251117143024.txt"),
            tempDirectory.appendingPathComponent(".hidden.mp4")
        ]

        for url in recordings + nonRecordings {
            let data = "test".data(using: .utf8)!
            try data.write(to: url)
        }

        // When
        let results = try service.listRecordings()

        // Then
        XCTAssertEqual(results.count, 2, "Should only return REC-*.mp4 files")
        XCTAssertTrue(results.allSatisfy { $0.lastPathComponent.starts(with: "REC-") })
    }

    // MARK: - Error Tests

    func testFileErrorDescriptions() {
        let errors: [(FileManagerService.FileError, String)] = [
            (.invalidPath("/test"), "invalid"),
            (.directoryCreationFailed(NSError(domain: "test", code: 1)), "directory"),
            (.fileNotFound(URL(fileURLWithPath: "/test")), "not found"),
            (.fileOperationFailed(NSError(domain: "test", code: 1)), "operation"),
            (.metadataExtractionFailed(NSError(domain: "test", code: 1)), "metadata"),
            (.pathNotWritable("/test"), "writable")
        ]

        for (error, expectedSubstring) in errors {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Error description should contain '\(expectedSubstring)' for \(error)"
            )
        }
    }

    // MARK: - Metadata Extraction Tests (require real video file)

    /*
    // MANUAL TEST: Metadata extraction from real video
    func testGetVideoMetadata() async throws {
        // Given - create a real video file using VideoEncoder
        let encoder = VideoEncoder()
        let outputURL = tempDirectory.appendingPathComponent("test.mp4")

        try encoder.startEncoding(outputURL: outputURL, resolution: .hd, frameRate: .fps30)

        // Generate 90 frames (3 seconds @ 30fps)
        for i in 0..<90 {
            let pixelBuffer = createTestPixelBuffer(width: 1280, height: 720)
            let time = CMTime(value: CMTimeValue(i), timescale: 30)
            try encoder.appendFrame(pixelBuffer, at: time)
        }

        _ = try await encoder.finishEncoding()

        // When
        let metadata = try await service.getVideoMetadata(for: outputURL)

        // Then
        XCTAssertEqual(metadata.filename, "test.mp4")
        XCTAssertEqual(metadata.fileURL, outputURL)
        XCTAssertGreaterThan(metadata.fileSize, 0)
        XCTAssertGreaterThan(metadata.duration, 2.5)
        XCTAssertLessThan(metadata.duration, 3.5)
        XCTAssertEqual(metadata.resolution.width, 1280)
        XCTAssertEqual(metadata.resolution.height, 720)
        XCTAssertEqual(metadata.frameRate, 30)
        XCTAssertEqual(metadata.format, "MP4/H.264")
    }

    private func createTestPixelBuffer(width: Int, height: Int) -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            fatalError("Failed to create pixel buffer")
        }
        return buffer
    }
    */
}
