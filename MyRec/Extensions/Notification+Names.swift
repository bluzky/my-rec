//
//  Notification+Names.swift
//  MyRec
//
//  Created by Week 2 Implementation
//

import Foundation

public extension Notification.Name {
    static let startRecording = Notification.Name("startRecording")
    static let pauseRecording = Notification.Name("pauseRecording")
    static let stopRecording = Notification.Name("stopRecording")
    static let openSettings = Notification.Name("openSettings")
    static let recordingStateChanged = Notification.Name("recordingStateChanged")
    static let recordingStarted = Notification.Name("recordingStarted")
    static let recordingFinished = Notification.Name("recordingFinished")
    static let openPreview = Notification.Name("openPreview")
    static let previewDialogClosed = Notification.Name("previewDialogClosed")
    static let openTrim = Notification.Name("openTrim")
    static let closeTrim = Notification.Name("closeTrim")
    static let showDashboard = Notification.Name("showDashboard")
    static let recordingSaved = Notification.Name("recordingSaved")
    static let recordingDeleted = Notification.Name("recordingDeleted")
    static let countdownStarted = Notification.Name("countdownStarted")
    static let cancelCountdown = Notification.Name("cancelCountdown")
}
