import SwiftUI

/// Settings bar displayed during region selection (macOS native style)
///
/// Layout: [X] [Screen] [Window] [Region] | [Settings ▾] | [Cursor] [Camera] [Audio] [Mic] [MicLevel] | [Record]
struct SettingsBarView: View {
    // MARK: - Properties

    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var audioCaptureEngine: AudioCaptureEngine
    let regionSize: CGSize
    let onClose: () -> Void
    let onRecord: () -> Void
    let isRecording: Bool

    @State private var isHoveringRecord = false
    @State private var isPressingRecord = false
    @State private var hasCheckedMicrophonePermission = false

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.primary.opacity(0.7))
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 6)

            // Capture mode buttons: Screen, Window, Region
            HStack(spacing: 8) {
                CaptureButton(
                    icon: "rectangle.fill",
                    isSelected: false,
                    help: "Select Entire Screen"
                ) { }

                CaptureButton(
                    icon: "macwindow",
                    isSelected: false,
                    help: "Select Window"
                ) { }

                CaptureButton(
                    icon: "rectangle.dashed",
                    isSelected: true,
                    help: "Select Region"
                ) { }
            }
            .padding(.horizontal, 8)

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 6)

            // Settings dropdown (FPS + Resolution) - Shows current values
            Menu {
                Section("Frame Rate") {
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps15 }) {
                        HStack {
                            Text("15 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps15 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps24 }) {
                        HStack {
                            Text("24 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps24 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps30 }) {
                        HStack {
                            Text("30 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps30 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps60 }) {
                        HStack {
                            Text("60 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps60 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                }

                Section("Resolution") {
                    Button(action: { settingsManager.defaultSettings.resolution = .hd }) {
                        HStack {
                            Text("720P")
                            if settingsManager.defaultSettings.resolution == .hd {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                    Button(action: { settingsManager.defaultSettings.resolution = .fullHD }) {
                        HStack {
                            Text("1080P")
                            if settingsManager.defaultSettings.resolution == .fullHD {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                    Button(action: { settingsManager.defaultSettings.resolution = .twoK }) {
                        HStack {
                            Text("2K")
                            if settingsManager.defaultSettings.resolution == .twoK {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                    Button(action: { settingsManager.defaultSettings.resolution = .fourK }) {
                        HStack {
                            Text("4K")
                            if settingsManager.defaultSettings.resolution == .fourK {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(isRecording)
                }
            } label: {
                VStack(spacing: 0) {
                    Text(settingsManager.defaultSettings.resolution.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary.opacity(isRecording ? 0.5 : 1.0))
                    Text(settingsManager.defaultSettings.frameRate.displayName.uppercased())
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(isRecording ? 0.35 : 0.65))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 70)
            }
            .menuStyle(.borderlessButton)
            .disabled(isRecording)
            .accessibilityLabel("Quality Settings")

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 6)

            // Toggle buttons: Cursor, Camera, System Audio, Microphone
            HStack(spacing: 8) {
                ToggleIconButton(
                    icon: "cursorarrow.rays",
                    isOn: $settingsManager.defaultSettings.cursorEnabled,
                    help: "Capture Cursor",
                    isDisabled: isRecording
                )

                ToggleIconButton(
                    icon: "video.fill",
                    isOn: $settingsManager.defaultSettings.cameraEnabled,
                    help: "Camera",
                    isDisabled: isRecording,
                    onIcon: "video.fill",
                    offIcon: "video.slash.fill"
                )

                ToggleIconButton(
                    icon: "speaker.wave.2.fill",
                    isOn: $settingsManager.defaultSettings.audioEnabled,
                    help: "System Sound",
                    isDisabled: isRecording,
                    onIcon: "speaker.wave.2.fill",
                    offIcon: "speaker.slash.fill"
                )

                // Microphone toggle with integrated vertical level indicator
                HStack(spacing: 4) {
                    ToggleIconButton(
                        icon: "mic.fill",
                        isOn: $settingsManager.defaultSettings.microphoneEnabled,
                        help: "Microphone",
                        isDisabled: isRecording,
                        onIcon: "mic.fill",
                        offIcon: "mic.slash.fill"
                    )

                    // Vertical microphone level indicator (always visible)
                    AudioLevelIndicator(
                        level: audioCaptureEngine.microphoneLevel,
                        orientation: .vertical
                    )
                    .frame(width: 6, height: 32)
                    .opacity(settingsManager.defaultSettings.microphoneEnabled ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 8)
            .onChange(of: settingsManager.defaultSettings.microphoneEnabled) { isEnabled in
                // Start/stop microphone monitoring based on toggle state
                if isEnabled {
                    Task {
                        let granted = await audioCaptureEngine.requestMicrophonePermission()
                        if granted {
                            audioCaptureEngine.startMicrophoneMonitoring()
                        } else {
                            // Reset toggle if permission denied
                            await MainActor.run {
                                settingsManager.defaultSettings.microphoneEnabled = false
                            }
                        }
                    }
                } else {
                    audioCaptureEngine.stopMicrophoneMonitoring()
                }
            }

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 6)

            // Record button with circle icon and animations
            Button(action: onRecord) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: isPressingRecord ? 24 : (isHoveringRecord ? 30 : 28),
                               height: isPressingRecord ? 24 : (isHoveringRecord ? 30 : 28))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringRecord)
                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPressingRecord)
                    Circle()
                        .strokeBorder(Color.white.opacity(isHoveringRecord ? 0.6 : 0.4), lineWidth: 2.5)
                        .frame(width: 38, height: 38)
                        .animation(.easeInOut(duration: 0.2), value: isHoveringRecord)
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(.plain)
            .disabled(isRecording)
            .opacity(isRecording ? 0.5 : 1.0)
            .onHover { hovering in
                isHoveringRecord = hovering && !isRecording
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isRecording {
                            isPressingRecord = true
                        }
                    }
                    .onEnded { _ in
                        isPressingRecord = false
                    }
            )
            .accessibilityLabel("Start Recording")
            .accessibilityHint("Begins screen recording after countdown")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                .cornerRadius(12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onAppear {
            // Check microphone permission on appear
            checkAndStartMicrophoneMonitoring()
        }
        .onDisappear {
            // Stop microphone monitoring when view disappears
            if audioCaptureEngine.isMicrophoneMonitoring {
                audioCaptureEngine.stopMicrophoneMonitoring()
                print("🛑 Stopped microphone monitoring (view disappeared)")
            }
        }
    }

    // MARK: - Helper Methods

    private func checkAndStartMicrophoneMonitoring() {
        guard !hasCheckedMicrophonePermission else { return }
        hasCheckedMicrophonePermission = true

        // Check if we already have microphone permission (without requesting)
        let hasPermission = audioCaptureEngine.checkMicrophonePermission()

        if hasPermission && settingsManager.defaultSettings.microphoneEnabled {
            // Has permission and toggle is enabled - start monitoring
            audioCaptureEngine.startMicrophoneMonitoring()
            print("✅ Auto-started microphone monitoring (permission granted)")
        } else if !hasPermission && settingsManager.defaultSettings.microphoneEnabled {
            // No permission but toggle is on - disable it
            settingsManager.defaultSettings.microphoneEnabled = false
            print("⚠️ Microphone permission not granted - toggle disabled")
        } else {
            print("ℹ️ Microphone toggle is off - monitoring not started")
        }
    }

}

// MARK: - Capture Button Component

/// Icon-based button for capture modes (matching macOS native style)
struct CaptureButton: View {
    let icon: String
    let isSelected: Bool
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary.opacity(isSelected ? 0.9 : (isHovering ? 0.75 : 0.6)))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.primary.opacity(0.15) : (isHovering ? Color.primary.opacity(0.08) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(isSelected ? 0.25 : (isHovering ? 0.18 : 0.12)), lineWidth: 1)
                )
                .scaleEffect(isHovering && !isSelected ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel(help)
    }
}

// MARK: - Toggle Icon Button Component

/// Toggle button for settings bar (cursor, camera, audio, mic)
struct ToggleIconButton: View {
    let icon: String
    @Binding var isOn: Bool
    let help: String
    var isDisabled: Bool = false

    // Optional custom icons for on/off states
    var onIcon: String?
    var offIcon: String?

    @State private var isHovering = false

    // Computed property to determine which icon to use
    private var displayIcon: String {
        if let onIcon = onIcon, let offIcon = offIcon {
            return isOn ? onIcon : offIcon
        }
        return icon
    }

    var body: some View {
        Button(action: {
            if !isDisabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
        }) {
            Image(systemName: displayIcon)
                .font(.system(size: 18))
                .foregroundColor(.primary.opacity(isDisabled ? 0.3 : (isOn ? 0.9 : (isHovering ? 0.65 : 0.5))))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? Color.primary.opacity(0.15) : (isHovering && !isDisabled ? Color.primary.opacity(0.05) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(isOn ? 0.25 : (isHovering && !isDisabled ? 0.18 : 0.12)), lineWidth: 1)
                )
                .scaleEffect(isOn ? 1.0 : (isHovering && !isDisabled ? 1.05 : 1.0))
                .animation(.easeInOut(duration: 0.15), value: isHovering)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(help)
        .onHover { hovering in
            isHovering = hovering && !isDisabled
        }
        .accessibilityLabel(help)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Visual Effect Blur

/// NSVisualEffectView wrapper for SwiftUI
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsBarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal state
            ZStack {
                Color.gray.opacity(0.3)
                VStack {
                    Spacer()
                    SettingsBarView(
                        settingsManager: SettingsManager.shared,
                        audioCaptureEngine: AudioCaptureEngine(),
                        regionSize: CGSize(width: 1440, height: 875),
                        onClose: {},
                        onRecord: {},
                        isRecording: false
                    )
                    .padding(.bottom, 40)
                }
            }
            .frame(width: 1200, height: 800)
            .previewDisplayName("Normal State")

            // Recording state (disabled controls)
            ZStack {
                Color.gray.opacity(0.3)
                VStack {
                    Spacer()
                    SettingsBarView(
                        settingsManager: SettingsManager.shared,
                        audioCaptureEngine: AudioCaptureEngine(),
                        regionSize: CGSize(width: 1440, height: 875),
                        onClose: {},
                        onRecord: {},
                        isRecording: true
                    )
                    .padding(.bottom, 40)
                }
            }
            .frame(width: 1200, height: 800)
            .previewDisplayName("Recording State (Disabled)")
        }
    }
}
#endif
