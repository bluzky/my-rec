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
            .help("Close")

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
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps24 }) {
                        HStack {
                            Text("24 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps24 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps30 }) {
                        HStack {
                            Text("30 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps30 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { settingsManager.defaultSettings.frameRate = .fps60 }) {
                        HStack {
                            Text("60 FPS")
                            if settingsManager.defaultSettings.frameRate == .fps60 {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
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
                    Button(action: { settingsManager.defaultSettings.resolution = .fullHD }) {
                        HStack {
                            Text("1080P")
                            if settingsManager.defaultSettings.resolution == .fullHD {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { settingsManager.defaultSettings.resolution = .twoK }) {
                        HStack {
                            Text("2K")
                            if settingsManager.defaultSettings.resolution == .twoK {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    Button(action: { settingsManager.defaultSettings.resolution = .fourK }) {
                        HStack {
                            Text("4K")
                            if settingsManager.defaultSettings.resolution == .fourK {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 0) {
                    Text(settingsManager.defaultSettings.resolution.rawValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Text(settingsManager.defaultSettings.frameRate.displayName.uppercased())
                        .font(.system(size: 12))
                        .foregroundColor(.primary.opacity(0.65))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: 70)
            }
            .menuStyle(.borderlessButton)
            .help("Settings")

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 6)

            // Toggle buttons: Cursor, Camera, System Audio, Microphone
            HStack(spacing: 8) {
                ToggleIconButton(
                    icon: "cursorarrow.rays",
                    isOn: $settingsManager.defaultSettings.cursorEnabled,
                    help: "Capture Cursor"
                )

                ToggleIconButton(
                    icon: "video.fill",
                    isOn: $settingsManager.defaultSettings.cameraEnabled,
                    help: "Camera"
                )

                ToggleIconButton(
                    icon: "speaker.wave.2.fill",
                    isOn: $settingsManager.defaultSettings.audioEnabled,
                    help: "System Sound"
                )

                ToggleIconButton(
                    icon: "mic.fill",
                    isOn: $settingsManager.defaultSettings.microphoneEnabled,
                    help: "Microphone"
                )
            }
            .padding(.horizontal, 8)

            Divider()
                .frame(height: 30)
                .padding(.horizontal, 6)

            // Record button with circle icon
            Button(action: onRecord) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                    Circle()
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 2.5)
                        .frame(width: 38, height: 38)
                }
                .frame(width: 50, height: 50)
            }
            .buttonStyle(.plain)
            .help("Start Recording")
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

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary.opacity(isSelected ? 0.9 : 0.6))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.primary.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(isSelected ? 0.25 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Toggle Icon Button Component

/// Toggle button for settings bar (cursor, camera, audio, mic)
struct ToggleIconButton: View {
    let icon: String
    @Binding var isOn: Bool
    let help: String

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.primary.opacity(isOn ? 0.9 : 0.5))
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? Color.primary.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(isOn ? 0.25 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
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
        ZStack {
            // Simulate overlay background
            Color.gray.opacity(0.3)

            VStack {
                Spacer()
                SettingsBarView(
                    settingsManager: SettingsManager.shared,
                    regionSize: CGSize(width: 1440, height: 875),
                    onClose: {},
                    onRecord: {}
                )
                .padding(.bottom, 40)
            }
        }
        .frame(width: 1200, height: 800)
    }
}
#endif
