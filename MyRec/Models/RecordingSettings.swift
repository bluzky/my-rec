import Foundation

struct RecordingSettings: Codable, Equatable {
    var resolution: Resolution
    var frameRate: FrameRate
    var audioEnabled: Bool
    var microphoneEnabled: Bool
    var cameraEnabled: Bool
    var cursorEnabled: Bool

    static let `default` = RecordingSettings(
        resolution: .fullHD,
        frameRate: .fps30,
        audioEnabled: true,
        microphoneEnabled: false,
        cameraEnabled: false,
        cursorEnabled: true
    )
}
