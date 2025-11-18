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
    static let recordingFrameCaptured = Notification.Name("recordingFrameCaptured")
    static let openPreview = Notification.Name("openPreview")
    static let openTrim = Notification.Name("openTrim")
    static let closeTrim = Notification.Name("closeTrim")
    static let showDashboard = Notification.Name("showDashboard")
}
