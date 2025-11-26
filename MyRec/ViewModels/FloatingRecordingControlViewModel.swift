//
//  FloatingRecordingControlViewModel.swift
//  MyRec
//
//  View model for floating recording control
//

import Foundation
import Combine

class FloatingRecordingControlViewModel: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isPaused: Bool = false
    @Published var isRecording: Bool = false  // Track if actually recording (not just countdown)
    @Published var shouldShowCollapsible: Bool = false  // Show collapse handle when inside recording region
    @Published var isCollapsed: Bool = false  // Track collapse state for window positioning

    private var startTime: Date?
    private var pausedTime: TimeInterval = 0
    private var timer: Timer?
    private var recordingStateObserver: Any?
    private var countdownObserver: Any?

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Listen for recording state changes
        recordingStateObserver = NotificationCenter.default.addObserver(
            forName: .recordingStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let state = notification.object as? RecordingState else { return }
            self?.handleRecordingStateChanged(state)
        }

        // Listen for countdown start to reset timer for the new session
        countdownObserver = NotificationCenter.default.addObserver(
            forName: .countdownStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resetForCountdown()
        }
    }

    private func handleRecordingStateChanged(_ state: RecordingState) {
        switch state {
        case .recording(let startTime):
            self.startTime = startTime
            self.isPaused = false
            self.isRecording = true
            startTimer()

        case .paused(let elapsedTime):
            self.pausedTime = elapsedTime
            self.isPaused = true
            stopTimer()

        case .idle:
            stopTimer()
            reset()
        }
    }

    private func startTimer() {
        // Invalidate existing timer if any
        timer?.invalidate()

        // Create new timer that fires every 100ms for smooth updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateElapsedTime()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsedTime() {
        guard let startTime = startTime else { return }

        if isPaused {
            elapsedTime = pausedTime
        } else {
            elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func reset() {
        startTime = nil
        pausedTime = 0
        elapsedTime = 0
        isPaused = false
        isRecording = false
        isCollapsed = false
    }

    private func resetForCountdown() {
        stopTimer()
        startTime = nil
        pausedTime = 0
        elapsedTime = 0
        isPaused = false
        isRecording = false
    }

    // MARK: - Formatted Time

    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Actions

    func togglePause() {
        if isPaused {
            // Resume recording
            print("▶️ Resuming recording")
            NotificationCenter.default.post(
                name: .recordingStateChanged,
                object: RecordingState.recording(startTime: Date().addingTimeInterval(-pausedTime))
            )
        } else {
            // Pause recording
            print("⏸ Pausing recording")
            NotificationCenter.default.post(
                name: .recordingStateChanged,
                object: RecordingState.paused(elapsedTime: elapsedTime)
            )
        }
    }

    func stopRecording() {
        print("⏹ Stopping recording from floating control")
        NotificationCenter.default.post(
            name: .stopRecording,
            object: nil
        )
    }

    func cancelOrStopRecording() {
        if isRecording {
            // Actually recording, so stop it
            stopRecording()
        } else {
            // In countdown mode, cancel it
            print("❌ Canceling countdown from floating control")
            NotificationCenter.default.post(
                name: .cancelCountdown,
                object: nil
            )
        }
    }

    deinit {
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = countdownObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        stopTimer()
    }
}
