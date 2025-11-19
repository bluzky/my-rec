import SwiftUI

/// Visual indicator for audio levels with real-time monitoring
struct AudioLevelIndicator: View {
    @ObservedObject var audioEngine: AudioCaptureEngine
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            // Audio icon with dynamic color based on level
            Image(systemName: "speaker.wave.2.fill")
                .foregroundColor(audioEngine.audioLevel > 0.01 ? .green : .gray)
                .font(.system(size: 12))

            // Label
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            // Level bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Active level bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(levelColor)
                        .frame(width: geometry.size.width * CGFloat(audioEngine.audioLevel))
                        .animation(.linear(duration: 0.1), value: audioEngine.audioLevel)
                }
            }
            .frame(height: 4)

            // Percentage display
            Text(String(format: "%.0f%%", audioEngine.audioLevel * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 35, alignment: .trailing)
                .monospacedDigit()
        }
    }

    /// Color based on audio level (green -> yellow -> red)
    private var levelColor: Color {
        switch audioEngine.audioLevel {
        case 0..<0.3:
            return .green
        case 0.3..<0.7:
            return .yellow
        case 0.7...1.0:
            return .red
        default:
            return .gray
        }
    }
}

/// Preview provider for development
#Preview {
    VStack(spacing: 20) {
        // Low level
        AudioLevelIndicator(
            audioEngine: {
                let engine = AudioCaptureEngine()
                Task { @MainActor in
                    engine.audioLevel = 0.2
                }
                return engine
            }(),
            label: "System"
        )
        .frame(width: 150)

        // Medium level
        AudioLevelIndicator(
            audioEngine: {
                let engine = AudioCaptureEngine()
                Task { @MainActor in
                    engine.audioLevel = 0.5
                }
                return engine
            }(),
            label: "Mic"
        )
        .frame(width: 150)

        // High level
        AudioLevelIndicator(
            audioEngine: {
                let engine = AudioCaptureEngine()
                Task { @MainActor in
                    engine.audioLevel = 0.85
                }
                return engine
            }(),
            label: "Audio"
        )
        .frame(width: 150)
    }
    .padding()
    .background(Color.black.opacity(0.9))
}
