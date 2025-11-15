import AppKit
import AVFoundation
import ScreenCaptureKit

enum PermissionType {
    case screenRecording
    case microphone
    case camera
}

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    // MARK: - Screen Recording Permission

    func checkScreenRecordingPermission() async -> PermissionStatus {
        do {
            _ = try await SCShareableContent.current
            return .granted
        } catch {
            return .denied
        }
    }

    func requestScreenRecordingPermission() async -> Bool {
        let status = await checkScreenRecordingPermission()

        if status == .denied {
            await MainActor.run {
                showPermissionAlert(for: .screenRecording)
            }
            return false
        }

        return status == .granted
    }

    // MARK: - Microphone Permission

    func checkMicrophonePermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestMicrophonePermission() async -> Bool {
        let status = checkMicrophonePermission()

        if status == .granted {
            return true
        }

        if status == .denied {
            await MainActor.run {
                showPermissionAlert(for: .microphone)
            }
            return false
        }

        return await AVCaptureDevice.requestAccess(for: .audio)
    }

    // MARK: - Camera Permission

    func checkCameraPermission() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    func requestCameraPermission() async -> Bool {
        let status = checkCameraPermission()

        if status == .granted {
            return true
        }

        if status == .denied {
            await MainActor.run {
                showPermissionAlert(for: .camera)
            }
            return false
        }

        return await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Alert Helper

    private func showPermissionAlert(for type: PermissionType) {
        let alert = NSAlert()
        alert.alertStyle = .warning

        switch type {
        case .screenRecording:
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = """
            Please enable screen recording permission in \
            System Settings → Privacy & Security → Screen Recording.
            """

        case .microphone:
            alert.messageText = "Microphone Permission Required"
            alert.informativeText = """
            Please enable microphone access in \
            System Settings → Privacy & Security → Microphone.
            """

        case .camera:
            alert.messageText = "Camera Permission Required"
            alert.informativeText = """
            Please enable camera access in \
            System Settings → Privacy & Security → Camera.
            """
        }

        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openSystemPreferences(for: type)
        }
    }

    private func openSystemPreferences(for type: PermissionType) {
        let urlString: String

        switch type {
        case .screenRecording:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .camera:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
