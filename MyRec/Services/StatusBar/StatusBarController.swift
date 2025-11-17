//
//  StatusBarController.swift
//  MyRec
//
//  Created by Week 2 Implementation
//

import AppKit
import Combine

public class StatusBarController: NSObject, ObservableObject {
    public var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var recordingView: NSView?
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var simulatedFileSize: Int64 = 0
    @Published var currentResolution = "1920×1080 @ 30 FPS"

    // UI components for inline recording controls
    private var timerLabel: NSTextField?
    private var pauseButton: NSButton?
    private var stopButton: NSButton?

    // Menu items that need state updates (for idle state only)
    private var recordMenuItem: NSMenuItem?

    public override init() {
        super.init()
        setupStatusItem()
        buildMenu()
        observeRecordingState()
    }

    deinit {
        timer?.invalidate()
        cancellables.removeAll()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        updateIdleDisplay()
    }

    private func updateIdleDisplay() {
        guard let button = statusItem?.button else { return }

        // Remove any custom view
        statusItem?.button?.subviews.forEach { $0.removeFromSuperview() }

        // Set icon for idle state
        button.image = NSImage(
            systemSymbolName: "record.circle",
            accessibilityDescription: "MyRec"
        )
        button.target = self
        button.action = #selector(statusBarButtonClicked)

        // Build idle menu
        buildIdleMenu()
        statusItem?.menu = menu
    }

    private func updateRecordingDisplay() {
        guard let button = statusItem?.button else { return }

        // Remove icon and action
        button.image = nil
        button.action = nil

        // Create custom view for inline controls
        createRecordingControls()

        // Remove menu during recording
        statusItem?.menu = nil
    }

    private func createRecordingControls() {
        guard let button = statusItem?.button else { return }

        // Create container view
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Timer label
        let timerLabel = NSTextField(labelWithString: "00:00:00")
        timerLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        timerLabel.textColor = NSColor.labelColor
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        self.timerLabel = timerLabel

        // Pause button
        let pauseButton = NSButton()
        pauseButton.title = ""
        pauseButton.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "Pause")
        pauseButton.bezelStyle = .texturedRounded
        pauseButton.isBordered = false
        pauseButton.imageScaling = .scaleProportionallyUpOrDown
        pauseButton.target = self
        pauseButton.action = #selector(pauseRecording)
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        pauseButton.focusRingType = .none
        self.pauseButton = pauseButton

        // Stop button
        let stopButton = NSButton()
        stopButton.title = ""
        stopButton.image = NSImage(systemSymbolName: "stop.circle.fill", accessibilityDescription: "Stop")
        stopButton.bezelStyle = .texturedRounded
        stopButton.isBordered = false
        stopButton.imageScaling = .scaleProportionallyUpOrDown
        stopButton.target = self
        stopButton.action = #selector(stopRecording)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.focusRingType = .none
        self.stopButton = stopButton

        // Add to container
        containerView.addSubview(timerLabel)
        containerView.addSubview(pauseButton)
        containerView.addSubview(stopButton)

        // Set up constraints
        NSLayoutConstraint.activate([
            // Timer label
            timerLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            timerLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            // Pause button
            pauseButton.leadingAnchor.constraint(equalTo: timerLabel.trailingAnchor, constant: 8),
            pauseButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            pauseButton.widthAnchor.constraint(equalToConstant: 24),
            pauseButton.heightAnchor.constraint(equalToConstant: 24),

            // Stop button
            stopButton.leadingAnchor.constraint(equalTo: pauseButton.trailingAnchor, constant: 4),
            stopButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 24),
            stopButton.heightAnchor.constraint(equalToConstant: 24),
            stopButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),

            // Container size
            containerView.widthAnchor.constraint(equalToConstant: 140),
            containerView.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Add as subview to status bar button
        button.addSubview(containerView)
        self.recordingView = containerView

        // Set up constraints to fill the button
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: button.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        // Initial update
        updateRecordingControls()
    }

    private func updateRecordingControls() {
        // Update timer display
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) % 3600 / 60
        let seconds = Int(elapsedTime) % 60
        let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        timerLabel?.stringValue = timeString

        // Update pause button
        if isPaused {
            pauseButton?.image = NSImage(systemSymbolName: "play.circle.fill", accessibilityDescription: "Resume")
        } else {
            pauseButton?.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "Pause")
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        buildIdleMenu()
        statusItem?.menu = menu
    }

    private func buildIdleMenu() {
        menu?.removeAllItems()

        // Title item
        let titleItem = NSMenuItem(title: "● MyRec", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu?.addItem(titleItem)

        menu?.addItem(NSMenuItem.separator())

        // Dashboard
        let dashboardMenuItem = NSMenuItem(
            title: "🏠 Show Dashboard",
            action: #selector(showDashboard),
            keyEquivalent: ""
        )
        dashboardMenuItem.target = self
        menu?.addItem(dashboardMenuItem)

        menu?.addItem(NSMenuItem.separator())

        // Record option
        recordMenuItem = NSMenuItem(
            title: "▶ Start Recording",
            action: #selector(recordScreen),
            keyEquivalent: ""
        )
        recordMenuItem?.target = self
        menu?.addItem(recordMenuItem!)

        menu?.addItem(NSMenuItem.separator())

        // Settings
        let settingsMenuItem = NSMenuItem(
            title: "⚙ Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.target = self
        menu?.addItem(settingsMenuItem)

        menu?.addItem(NSMenuItem.separator())

        // About and Quit
        let aboutMenuItem = NSMenuItem(
            title: "About MyRec",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutMenuItem.target = self
        menu?.addItem(aboutMenuItem)

        let quitMenuItem = NSMenuItem(
            title: "Quit MyRec",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu?.addItem(quitMenuItem)
    }

    
    private func observeRecordingState() {
        // Subscribe to RecordingManager state changes
        NotificationCenter.default.publisher(for: .recordingStateChanged)
            .sink { [weak self] notification in
                guard let state = notification.object as? RecordingState else { return }
                self?.updateMenuForState(state)
            }
            .store(in: &cancellables)

        // Listen for pause notifications (for demo purposes)
        NotificationCenter.default.publisher(for: .pauseRecording)
            .sink { [weak self] _ in
                guard let self = self, self.isRecording else { return }

                // Toggle pause state for demo
                if !self.isPaused {
                    print("🔄 StatusBarController: Handling pause notification - switching to paused")
                    self.updateMenuForState(.paused(elapsedTime: self.elapsedTime))
                } else {
                    print("🔄 StatusBarController: Handling pause notification - switching to recording")
                    self.updateMenuForState(.recording(startTime: Date().addingTimeInterval(-self.elapsedTime)))
                }
            }
            .store(in: &cancellables)

        // Listen for stop notifications
        NotificationCenter.default.publisher(for: .stopRecording)
            .sink { [weak self] _ in
                guard let self = self else { return }
                print("🔄 StatusBarController: Handling stop notification - switching to idle")
                self.updateMenuForState(.idle)
            }
            .store(in: &cancellables)
    }

    private func updateMenuForState(_ state: RecordingState) {
        print("🔄 StatusBarController: Updating menu for state: \(state)")
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .idle:
                print("🔄 StatusBarController: Switching to idle display")
                self?.updateIdleDisplay()
                self?.stopTimer()
                self?.resetTimer()
                self?.isRecording = false
                self?.isPaused = false

            case .recording:
                print("🔄 StatusBarController: Switching to recording display")
                self?.updateRecordingDisplay()
                self?.startTimer()
                self?.isRecording = true
                self?.isPaused = false

            case .paused:
                print("🔄 StatusBarController: Switching to paused display")
                self?.updateRecordingDisplay()
                self?.stopTimer()
                self?.isRecording = true
                self?.isPaused = true
            }
        }
    }

    // MARK: - Timer Management

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetTimer() {
        elapsedTime = 0
        simulatedFileSize = 0
    }

    private func updateTimer() {
        elapsedTime += 1

        // Simulate file size growth (average ~5MB/s for 1080p30)
        simulatedFileSize = Int64(Double(elapsedTime) * 5.2)

        // Update inline recording controls
        updateRecordingControls()
    }

    
    @objc private func statusBarButtonClicked() {
        // Optional: Handle left-click on status bar icon
        // For now, clicking shows the menu (default behavior)
    }

    // MARK: - Menu Actions

    @objc func recordScreen() {
        NotificationCenter.default.post(
            name: .startRecording,
            object: nil
        )
    }

    @objc func pauseRecording() {
        print("⏸ Pause/Resume button clicked from system tray")

        if isRecording && !isPaused {
            // Currently recording, pause it
            isPaused = true
            print("⏸ Pausing recording - posting notification")
            NotificationCenter.default.post(
                name: .pauseRecording,
                object: nil
            )
        } else if isRecording && isPaused {
            // Currently paused, resume it
            isPaused = false
            print("▶ Resuming recording - posting notification")
            NotificationCenter.default.post(
                name: .pauseRecording,
                object: nil
            )
        }
    }

    @objc func stopRecording() {
        print("⏹ Stop button clicked from system tray")
        print("⏹ Stopping recording - posting notification")

        // Reset state immediately
        isRecording = false
        isPaused = false

        NotificationCenter.default.post(
            name: .stopRecording,
            object: nil
        )
    }

    @objc func openSettings() {
        NotificationCenter.default.post(
            name: .openSettings,
            object: nil
        )
    }

    @objc func showDashboard() {
        NotificationCenter.default.post(
            name: .showDashboard,
            object: nil
        )
    }

    @objc func showAbout() {
        // TODO: Implement About dialog
        print("ℹ️ About MyRec requested - not yet implemented")
        // Will show About dialog when implemented
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Public Methods for Testing

    /// Simulate recording state change for UI testing
    public func simulateRecordingState(_ state: RecordingState) {
        // Post notification to trigger the observer system (same as real RecordingManager)
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: state
        )
    }
}
