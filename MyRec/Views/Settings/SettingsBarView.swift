import SwiftUI

/// Settings bar displayed during region selection (macOS native style)
///
/// Layout: [X] [Screen] [Window] [Region] | [Settings ▾] | [Cursor] [Camera] [Audio] [Mic] | [Record]
struct SettingsBarView: View {
    // MARK: - Properties

    @ObservedObject var settingsManager: SettingsManager
    let regionSize: CGSize
    let onClose: () -> Void
    let onRecord: () -> Void
    let isRecording: Bool

    @State private var isHoveringRecord = false
    @State private var isPressingRecord = false

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
            .delayedTooltip("Close region selection", delay: 2.0)

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
                .delayedTooltip("Record entire screen", delay: 2.0)

                CaptureButton(
                    icon: "macwindow",
                    isSelected: false,
                    help: "Select Window"
                ) { }
                .delayedTooltip("Record a specific window", delay: 2.0)

                CaptureButton(
                    icon: "rectangle.dashed",
                    isSelected: true,
                    help: "Select Region"
                ) { }
                .delayedTooltip("Record selected region", delay: 2.0)
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
            .delayedTooltip(isRecording ? "Cannot change settings while recording" : "Video quality settings (resolution & frame rate)", delay: 2.0)
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
                .delayedTooltip(isRecording ? "Cannot change while recording" : "Show/hide mouse cursor in recording", delay: 2.0)

                ToggleIconButton(
                    icon: "video.fill",
                    isOn: $settingsManager.defaultSettings.cameraEnabled,
                    help: "Camera",
                    isDisabled: isRecording
                )
                .delayedTooltip(isRecording ? "Cannot change while recording" : "Record webcam video", delay: 2.0)

                ToggleIconButton(
                    icon: "speaker.wave.2.fill",
                    isOn: $settingsManager.defaultSettings.audioEnabled,
                    help: "System Sound",
                    isDisabled: isRecording
                )
                .delayedTooltip(isRecording ? "Cannot change while recording" : "Record system audio", delay: 2.0)

                ToggleIconButton(
                    icon: "mic.fill",
                    isOn: $settingsManager.defaultSettings.microphoneEnabled,
                    help: "Microphone",
                    isDisabled: isRecording
                )
                .delayedTooltip(isRecording ? "Cannot change while recording" : "Record microphone audio", delay: 2.0)
            }
            .padding(.horizontal, 8)

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
            .delayedTooltip(isRecording ? "Recording in progress" : "Start recording (⌘⌥1)", delay: 2.0)
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

    @State private var isHovering = false

    var body: some View {
        Button(action: {
            if !isDisabled {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isOn.toggle()
                }
            }
        }) {
            Image(systemName: icon)
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

// MARK: - Delayed Tooltip

/// Custom tooltip that appears after hovering for specified duration
struct DelayedTooltip: ViewModifier {
    let text: String
    let delay: TimeInterval
    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showTooltip {
                    Text(text)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.black.opacity(0.9))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(y: -40)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(1000)
                }
            }
            .onHover { hovering in
                isHovering = hovering

                if hovering {
                    // Start timer for showing tooltip
                    hoverTask?.cancel()
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        if !Task.isCancelled {
                            await MainActor.run {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showTooltip = true
                                }
                            }
                        }
                    }
                } else {
                    // Cancel timer and hide tooltip
                    hoverTask?.cancel()
                    withAnimation(.easeOut(duration: 0.15)) {
                        showTooltip = false
                    }
                }
            }
    }
}

extension View {
    func delayedTooltip(_ text: String, delay: TimeInterval = 2.0) -> some View {
        self.modifier(DelayedTooltip(text: text, delay: delay))
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
