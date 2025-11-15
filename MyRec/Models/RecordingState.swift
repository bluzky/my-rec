import Foundation

enum RecordingState: Equatable {
    case idle
    case recording(startTime: Date)
    case paused(elapsedTime: TimeInterval)

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}
