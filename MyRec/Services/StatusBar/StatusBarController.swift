//
//  StatusBarController.swift
//  MyRec
//
//  Created by Week 2 Implementation
//

import AppKit
import Combine

public class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    @Published var isRecording = false
    @Published var isPaused = false
    @Published var elapsedTime: TimeInterval = 0

    // Menu items that need state updates
    private var recordMenuItem: NSMenuItem?
    private var pauseMenuItem: NSMenuItem?
    private var stopMenuItem: NSMenuItem?

    public override init() {
        super.init()
        setupStatusItem()
        buildMenu()
        observeRecordingState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "record.circle",
                accessibilityDescription: "MyRec"
            )
            button.target = self
            button.action = #selector(statusBarButtonClicked)
        }
    }

    private func buildMenu() {
        menu = NSMenu()

        recordMenuItem = NSMenuItem(
            title: "Record Screen",
            action: #selector(recordScreen),
            keyEquivalent: ""
        )
        recordMenuItem?.target = self
        menu?.addItem(recordMenuItem!)

        pauseMenuItem = NSMenuItem(
            title: "Pause",
            action: #selector(pauseRecording),
            keyEquivalent: ""
        )
        pauseMenuItem?.target = self
        pauseMenuItem?.isEnabled = false
        menu?.addItem(pauseMenuItem!)

        stopMenuItem = NSMenuItem(
            title: "Stop Recording",
            action: #selector(stopRecording),
            keyEquivalent: ""
        )
        stopMenuItem?.target = self
        stopMenuItem?.isEnabled = false
        menu?.addItem(stopMenuItem!)

        menu?.addItem(NSMenuItem.separator())

        let settingsMenuItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsMenuItem.target = self
        menu?.addItem(settingsMenuItem)

        menu?.addItem(NSMenuItem.separator())

        let quitMenuItem = NSMenuItem(
            title: "Quit MyRec",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitMenuItem.target = self
        menu?.addItem(quitMenuItem)

        statusItem?.menu = menu
    }

    private func observeRecordingState() {
        // Subscribe to RecordingManager state changes
        NotificationCenter.default.publisher(for: .recordingStateChanged)
            .sink { [weak self] notification in
                guard let state = notification.object as? RecordingState else { return }
                self?.updateMenuForState(state)
            }
            .store(in: &cancellables)
    }

    private func updateMenuForState(_ state: RecordingState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .idle:
                self?.recordMenuItem?.isEnabled = true
                self?.pauseMenuItem?.isEnabled = false
                self?.stopMenuItem?.isEnabled = false
                self?.updateIcon(recording: false)

            case .recording:
                self?.recordMenuItem?.isEnabled = false
                self?.pauseMenuItem?.isEnabled = true
                self?.pauseMenuItem?.title = "Pause"
                self?.stopMenuItem?.isEnabled = true
                self?.updateIcon(recording: true)

            case .paused:
                self?.recordMenuItem?.isEnabled = false
                self?.pauseMenuItem?.isEnabled = true
                self?.pauseMenuItem?.title = "Resume"
                self?.stopMenuItem?.isEnabled = true
                self?.updateIcon(recording: false)
            }
        }
    }

    private func updateIcon(recording: Bool) {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: recording ? "record.circle.fill" : "record.circle",
                accessibilityDescription: recording ? "Recording" : "MyRec"
            )
        }
    }

    @objc private func statusBarButtonClicked() {
        // Optional: Handle left-click on status bar icon
        // For now, clicking shows the menu (default behavior)
    }

    @objc func recordScreen() {
        NotificationCenter.default.post(
            name: .startRecording,
            object: nil
        )
    }

    @objc func pauseRecording() {
        NotificationCenter.default.post(
            name: .pauseRecording,
            object: nil
        )
    }

    @objc func stopRecording() {
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    deinit {
        cancellables.removeAll()
    }
}
