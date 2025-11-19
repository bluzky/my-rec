import SwiftUI

/// Visual indicator for audio levels with real-time monitoring
struct AudioLevelIndicator: View {
    let level: Float
    var label: String? = nil
    var showPercentage: Bool = false
    var orientation: Orientation = .horizontal

    enum Orientation {
        case horizontal
        case vertical
    }

    // Convenience initializer for legacy usage
    init(audioEngine: AudioCaptureEngine, label: String) {
        self.level = audioEngine.audioLevel
        self.label = label
        self.showPercentage = true
        self.orientation = .horizontal
    }

    // Primary initializer with just level
    init(level: Float, label: String? = nil, showPercentage: Bool = false, orientation: Orientation = .horizontal) {
        self.level = level
        self.label = label
        self.showPercentage = showPercentage
        self.orientation = orientation
    }

    var body: some View {
        Group {
            if orientation == .vertical {
                verticalBody
            } else {
                horizontalBody
            }
        }
    }

    private var horizontalBody: some View {
        HStack(spacing: 6) {
            // Label (optional)
            if let label = label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Level bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Active level bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(levelColor)
                        .frame(width: geometry.size.width * CGFloat(level))
                        .animation(.linear(duration: 0.1), value: level)
                }
            }
            .frame(height: 4)

            // Percentage display (optional)
            if showPercentage {
                Text(String(format: "%.0f%%", level * 100))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 35, alignment: .trailing)
                    .monospacedDigit()
            }
        }
    }

    private var verticalBody: some View {
        VStack(spacing: 0) {
            // Level bar (grows from bottom to top)
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))

                    // Active level bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(levelColor)
                        .frame(height: geometry.size.height * CGFloat(level))
                        .animation(.linear(duration: 0.1), value: level)
                }
            }
        }
    }

    /// Color based on audio level (green -> yellow -> red)
    private var levelColor: Color {
        switch level {
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
