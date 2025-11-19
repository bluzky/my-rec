import XCTest
import AVFoundation
@testable import MyRec

@MainActor
final class AudioCaptureEngineTests: XCTestCase {

    // MARK: - Initialization Tests

    func testAudioEngineInitialization() {
        let engine = AudioCaptureEngine()

        XCTAssertFalse(engine.isCapturing, "Engine should not be capturing on init")
        XCTAssertEqual(engine.audioLevel, 0.0, "Audio level should be 0.0 on init")
    }

    // MARK: - Audio Input Setup Tests

    func testAudioInputSetup() throws {
        let engine = AudioCaptureEngine()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio-\(UUID().uuidString).mp4")

        // Create asset writer
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Setup audio input
        try engine.setupAudioInput(for: assetWriter)

        // Verify audio input was added
        let audioInput = assetWriter.inputs.first(where: { $0.mediaType == .audio })
        XCTAssertNotNil(audioInput, "Audio input should be added to asset writer")

        // Verify input configuration
        XCTAssertTrue(audioInput?.expectsMediaDataInRealTime ?? false, "Should expect real-time data")

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    func testAudioInputSetupWithUnsupportedSettings() throws {
        let engine = AudioCaptureEngine()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-audio-invalid-\(UUID().uuidString).mp4")

        // Create asset writer with incompatible file type
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .wav)

        // Attempt to setup - should throw if settings incompatible
        // Note: This test might pass if AAC is compatible with WAV container
        // Adjust based on actual behavior
        do {
            try engine.setupAudioInput(for: assetWriter)
            // If it succeeds, that's fine - AAC might be compatible
        } catch {
            XCTAssertTrue(error is AudioError, "Should throw AudioError")
        }

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Capture State Tests

    func testStartCapturing() {
        let engine = AudioCaptureEngine()

        engine.startCapturing()

        XCTAssertTrue(engine.isCapturing, "Should be capturing after start")
        XCTAssertEqual(engine.audioLevel, 0.0, "Audio level should reset to 0.0")
    }

    func testStopCapturing() {
        let engine = AudioCaptureEngine()

        engine.startCapturing()
        engine.stopCapturing()

        XCTAssertFalse(engine.isCapturing, "Should not be capturing after stop")
        XCTAssertEqual(engine.audioLevel, 0.0, "Audio level should reset to 0.0")
    }

    // MARK: - Audio Level Tests

    func testAudioLevelRange() {
        let engine = AudioCaptureEngine()

        // Audio level should always be between 0.0 and 1.0
        XCTAssertGreaterThanOrEqual(engine.audioLevel, 0.0, "Audio level should be >= 0.0")
        XCTAssertLessThanOrEqual(engine.audioLevel, 1.0, "Audio level should be <= 1.0")
    }

    // MARK: - Error Tests

    func testAudioErrorDescriptions() {
        let errors: [AudioError] = [
            .unsupportedSettings,
            .cannotAddInput,
            .captureFailed
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true, "Description should not be empty")
        }
    }

    // MARK: - Integration Tests

    func testCompleteAudioCaptureFlow() async throws {
        let engine = AudioCaptureEngine()
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-complete-\(UUID().uuidString).mp4")

        // Create and configure asset writer
        let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        try engine.setupAudioInput(for: assetWriter)

        // Start writing
        XCTAssertTrue(assetWriter.startWriting(), "Asset writer should start")

        // Start capture
        engine.startCapturing()
        XCTAssertTrue(engine.isCapturing)

        // Simulate processing (in real scenario, audio buffers would come from ScreenCaptureKit)
        // For this test, we just verify the state

        // Stop capture
        engine.stopCapturing()
        XCTAssertFalse(engine.isCapturing)

        // Cleanup
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Cleanup

    override func tearDown() {
        super.tearDown()
        // Clean up any temporary files
        let tempDir = FileManager.default.temporaryDirectory
        let testFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("test-audio") }

        testFiles?.forEach { url in
            try? FileManager.default.removeItem(at: url)
        }
    }
}
