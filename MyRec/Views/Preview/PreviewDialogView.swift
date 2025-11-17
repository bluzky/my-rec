//
//  PreviewDialogView.swift
//  MyRec
//
//  Preview dialog for viewing recorded videos
//

import SwiftUI

struct PreviewDialogView: View {
    @StateObject var viewModel: PreviewDialogViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Video player - full width
            videoPlayerSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 500)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                // Action buttons on the right
                Button(action: { viewModel.trimVideo() }) {
                    Label("Trim", systemImage: "scissors")
                }
                .help("Trim Video")

                Button(action: { viewModel.showInFinder() }) {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Show in Finder")

                Button(action: { viewModel.deleteRecording() }) {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete Recording")

                Button(action: { viewModel.shareRecording() }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .help("Share")
            }
        }
        .onKeyPress(.space) {
            viewModel.togglePlayback()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            viewModel.seek(by: -5)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            viewModel.seek(by: 5)
            return .handled
        }
    }

    // MARK: - Video Player Section

    private var videoPlayerSection: some View {
        VStack(spacing: 0) {
            // Video preview area
            videoPlaceholder
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Playback controls
            playbackControlsBar
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.95))
        }
    }

    // MARK: - Video Placeholder

    private var videoPlaceholder: some View {
        ZStack {
            // Black background
            Color.black

            VStack(spacing: 16) {
                // Play/pause icon
                Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                    .shadow(radius: 8)
                    .onTapGesture {
                        viewModel.togglePlayback()
                    }

                Text("Video Preview Placeholder")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))

                Text(viewModel.recording.filename)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Playback Controls Bar

    private var playbackControlsBar: some View {
        VStack(spacing: 12) {
            // Row 1: Progress bar with time on the right
            HStack(spacing: 12) {
                // Seek slider
                Slider(
                    value: Binding(
                        get: { viewModel.progress },
                        set: { viewModel.seek(to: $0 * viewModel.recording.duration) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                .tint(.blue)

                // Time display: current / total
                Text("\(viewModel.currentTimeString) / \(viewModel.recording.durationString)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(minWidth: 120, alignment: .trailing)
            }

            // Row 2: Control buttons
            HStack(spacing: 16) {
                // Play/Pause button
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help(viewModel.isPlaying ? "Pause (Space)" : "Play (Space)")

                // Volume control with inline slider
                VolumeControlInline(viewModel: viewModel)

                Spacer()

                // Playback speed menu
                PlaybackSpeedMenu(viewModel: viewModel)

                // Fullscreen button placeholder
                Button(action: {}) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Fullscreen")
            }
        }
    }

}

// MARK: - Volume Control Inline

struct VolumeControlInline: View {
    @ObservedObject var viewModel: PreviewDialogViewModel

    var body: some View {
        HStack(spacing: 10) {
            // Volume icon button
            Button(action: { viewModel.toggleMute() }) {
                Image(systemName: volumeIcon)
                    .font(.title3)
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .help(viewModel.isMuted ? "Unmute" : "Mute")

            // Volume slider
            Slider(
                value: Binding(
                    get: { viewModel.volume },
                    set: { viewModel.setVolume($0) }
                ),
                in: 0...1
            )
            .controlSize(.mini)
            .tint(.blue)
            .frame(width: 80)
        }
    }

    private var volumeIcon: String {
        if viewModel.isMuted || viewModel.volume == 0 {
            return "speaker.slash.fill"
        } else if viewModel.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if viewModel.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Playback Speed Menu

struct PlaybackSpeedMenu: View {
    @ObservedObject var viewModel: PreviewDialogViewModel
    @State private var isShowingMenu = false

    var body: some View {
        Button(action: { isShowingMenu.toggle() }) {
            Text(viewModel.playbackSpeedString)
                .font(.system(.callout, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowingMenu, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                    Button(action: {
                        viewModel.setPlaybackSpeed(speed)
                        isShowingMenu = false
                    }) {
                        HStack(spacing: 12) {
                            Text(speedLabel(speed))
                                .font(.system(.body))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if viewModel.playbackSpeed == speed {
                                Image(systemName: "checkmark")
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if speed != 2.0 {
                        Divider()
                    }
                }
            }
            .frame(width: 120)
            .padding(.vertical, 4)
        }
        .help("Playback speed")
        .fixedSize()
    }

    private func speedLabel(_ speed: Double) -> String {
        if speed == 1.0 {
            return "Normal"
        } else if speed.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(speed))x"
        } else {
            return "\(speed)x"
        }
    }
}

// MARK: - Preview

#Preview {
    PreviewDialogView(viewModel: PreviewDialogViewModel(recording: .sample))
        .frame(width: 900, height: 600)
}
