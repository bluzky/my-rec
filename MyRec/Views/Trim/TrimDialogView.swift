//
//  TrimDialogView.swift
//  MyRec
//
//  Trim dialog for trimming recorded videos
//

import SwiftUI

struct TrimDialogView: View {
    @StateObject var viewModel: TrimDialogViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Frame preview section - full width, no padding
            framePreviewSection

            // Control bar section
            controlBarSection
        }
        .frame(width: 700, height: 500)
        .background(Color(red: 0.067, green: 0.094, blue: 0.153)) // Dark gray 900
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Action buttons on the right
                Button(action: { viewModel.save() }) {
                    Label("Save", systemImage: "checkmark.circle")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 14))
                }
                .buttonStyle(CompactToolbarButtonStyle())
                .help("Save and replace original")
                .disabled(viewModel.isTrimming)

                Button(action: { viewModel.saveAs() }) {
                    Label("Save As", systemImage: "square.and.arrow.down")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 14))
                }
                .buttonStyle(CompactToolbarButtonStyle())
                .help("Save as new file")
                .disabled(viewModel.isTrimming)
            }
        }
        .toolbarRole(.editor)
        .onKeyPress(.space) {
            viewModel.togglePlayback()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.seekByFrame(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.seekByFrame(1)
            return .handled
        }
        .sheet(isPresented: $viewModel.isTrimming) {
            trimProgressSheet
        }
    }

    // MARK: - Frame Preview Section

    private var framePreviewSection: some View {
        ZStack {
            // Frame preview placeholder - full width, no rounded corners
            Rectangle()
                .fill(viewModel.currentFrameColor.gradient)

            VStack(spacing: 8) {
                // Play/pause button overlay
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 6)
                }
                .buttonStyle(.plain)

                Text(viewModel.playheadTimeString)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.067, green: 0.094, blue: 0.153).opacity(0.6))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Control Bar Section

    private var controlBarSection: some View {
        VStack(spacing: 0) {
            // Combined control row
            HStack(spacing: 16) {
                // Left: Playback controls + Edit actions
                HStack(spacing: 16) {
                    // Playback controls
                    HStack(spacing: 12) {
                        // 15s backward
                        Button(action: { viewModel.seek(by: -15) }) {
                            Image(systemName: "gobackward.15")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Skip 15s backward")

                        // Play/Pause
                        Button(action: { viewModel.togglePlayback() }) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help(viewModel.isPlaying ? "Pause" : "Play")

                        // 15s forward
                        Button(action: { viewModel.seek(by: 15) }) {
                            Image(systemName: "goforward.15")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .help("Skip 15s forward")
                    }

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1, height: 20)

                    // Edit actions
                    HStack(spacing: 12) {
                        // Undo
                        Button(action: { viewModel.resetTrim() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(EditButtonStyle())
                        .help("Reset trim points")

                        // Trim to selection
                        Button(action: { viewModel.saveAs() }) {
                            Image(systemName: "scissors")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(EditButtonStyle())
                        .help("Trim to selection")

                        // Delete selection
                        Button(action: { viewModel.deleteSelection() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(EditButtonStyle())
                        .help("Delete selection")
                    }
                }

                Spacer()

                // Center: Time display
                Text("\(viewModel.startTimeString) / \(viewModel.endTimeString)")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))

                Spacer()

                // Right: Sound toggle
                Button(action: { viewModel.toggleMute() }) {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help(viewModel.isMuted ? "Unmute" : "Mute")
            }
            .frame(height: 40)
            .padding(.horizontal, 16)

            // Divider
            Divider()
                .background(Color.white.opacity(0.2))

            // Timeline with ruler
            TimelineView(viewModel: viewModel)
                .frame(height: 80)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .background(Color(red: 0.067, green: 0.094, blue: 0.153).opacity(0.95)) // Dark gray 900
    }

    // MARK: - Trim Progress Sheet

    private var trimProgressSheet: some View {
        VStack(spacing: 20) {
            Text("Trimming Video")
                .font(.title2)
                .fontWeight(.semibold)

            ProgressView(value: viewModel.trimProgress, total: 1.0)
                .progressViewStyle(.linear)
                .frame(width: 300)

            Text("\(Int(viewModel.trimProgress * 100))%")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)

            Text("Saving trimmed video...")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 400, height: 200)
    }
}

// MARK: - Timeline View Component

struct TimelineView: View {
    @ObservedObject var viewModel: TrimDialogViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Time ruler at top
                timeRulerView(width: geometry.size.width)
                    .frame(height: 20)

                // Timeline track with handles
                ZStack(alignment: .leading) {
                    // Background track (lighter so unselected regions are visible)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.4))
                        .frame(height: 60)

                    // Selected range highlight
                    selectedRangeOverlay(width: geometry.size.width)

                    // Start handle
                    trimHandle(
                        position: viewModel.normalizedStartPosition * geometry.size.width,
                        isStart: true,
                        totalWidth: geometry.size.width
                    )

                    // End handle
                    trimHandle(
                        position: viewModel.normalizedEndPosition * geometry.size.width,
                        isStart: false,
                        totalWidth: geometry.size.width
                    )

                    // Playhead scrubber (full height)
                    playheadScrubber(
                        position: viewModel.normalizedPlayheadPosition * geometry.size.width,
                        totalWidth: geometry.size.width,
                        fullHeight: geometry.size.height
                    )
                }
                .frame(height: 60)
            }
        }
    }

    // MARK: - Selected Range Overlay

    private func selectedRangeOverlay(width: CGFloat) -> some View {
        let startX = viewModel.normalizedStartPosition * width
        let endX = viewModel.normalizedEndPosition * width
        let rangeWidth = endX - startX

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(0.25))
                .frame(width: max(0, rangeWidth), height: 60)

            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.blue, lineWidth: 2)
                .frame(width: max(0, rangeWidth), height: 60)
        }
        .offset(x: startX)
    }

    // MARK: - Time Ruler View

    private func timeRulerView(width: CGFloat) -> some View {
        Canvas { context, size in
            let duration = viewModel.recording.duration

            // Calculate number of markers based on width
            let minSpacing: CGFloat = 60 // Minimum 60px between markers
            let maxMarkers = Int(size.width / minSpacing)
            let markerInterval: TimeInterval = calculateMarkerInterval(duration: duration, maxMarkers: maxMarkers)

            var currentTime: TimeInterval = 0
            while currentTime <= duration {
                let x = (currentTime / duration) * size.width
                let timeText = formatRulerTime(currentTime)

                // Draw time label
                let textPosition = CGPoint(x: x, y: 4)
                context.draw(
                    Text(timeText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white),
                    at: textPosition
                )

                currentTime += markerInterval
            }
        }
    }

    private func formatRulerTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Trim Handle (Pill Style)

    private func trimHandle(position: CGFloat, isStart: Bool, totalWidth: CGFloat) -> some View {
        // Large pill/capsule handle at 50% height
        Capsule()
            .fill(Color.blue)
            .frame(width: 16, height: 30)
            .overlay(
                Capsule()
                    .strokeBorder(Color.white, lineWidth: 2)
            )
            .offset(x: position - 8)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let normalized = min(max(value.location.x / totalWidth, 0), 1)
                        if isStart {
                            viewModel.setStartPosition(normalized)
                        } else {
                            viewModel.setEndPosition(normalized)
                        }
                    }
            )
            .help(isStart ? "Drag to set start time" : "Drag to set end time")
    }

    // MARK: - Playhead Scrubber (Timeline Height)

    private func playheadScrubber(position: CGFloat, totalWidth: CGFloat, fullHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Triangle at top (2/3 width) - shifted down 2px
            Triangle()
                .fill(Color.white)
                .frame(width: 13, height: 10)
                .offset(y: -6) // Extend above timeline (shifted down 2px)

            // Vertical line matching timeline box height (60px)
            Rectangle()
                .fill(Color.white)
                .frame(width: 1, height: 60)
                .offset(y: -6)
        }
        .offset(x: position - 6.5)
        .zIndex(10) // Display above connecting border
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let normalized = min(max(value.location.x / totalWidth, 0), 1)
                    viewModel.setPlayheadPosition(normalized)
                }
        )
        .help("Scrub to preview frames")
    }

    // MARK: - Helpers

    private func calculateMarkerInterval(duration: TimeInterval, maxMarkers: Int) -> TimeInterval {
        // Calculate optimal interval based on available width and duration
        let idealInterval = duration / Double(maxMarkers)

        // Round to nice intervals: 5s, 10s, 15s, 30s, 60s, 120s, 300s
        let niceIntervals: [TimeInterval] = [5, 10, 15, 30, 60, 120, 300, 600]

        // Find the smallest nice interval that's >= ideal interval
        for interval in niceIntervals {
            if interval >= idealInterval {
                return interval
            }
        }

        // For very long durations, use multiples of minutes
        let minutes = ceil(idealInterval / 60)
        return minutes * 60
    }
}

// MARK: - Triangle Shape (for playhead indicator)

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Triangle pointing down
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Edit Button Style (with hover and click effects)

struct EditButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        configuration.isPressed ? Color.blue.opacity(0.3) :
                        isHovered ? Color.white.opacity(0.15) : Color.clear
                    )
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Compact Toolbar Button Style

struct CompactToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.blue.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Preview

#Preview {
    TrimDialogView(viewModel: TrimDialogViewModel(recording: .sample))
}
