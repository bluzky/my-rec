//
//  PreviewDialogView.swift
//  MyRec
//
//  Preview dialog for viewing recorded videos
//

import SwiftUI
import AVKit

struct PreviewDialogView: View {
    @StateObject var viewModel: PreviewDialogViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Video player with built-in controls
            if let player = viewModel.player {
                GeometryReader { proxy in
                    let availableSize = proxy.size
                    let aspect = videoAspectRatio
                    // Fit the video to available space while preserving its aspect
                    let targetWidth = min(availableSize.width, availableSize.height * aspect)
                    let targetHeight = targetWidth / aspect

                    VStack {
                        Spacer(minLength: 0)
                        // Use an NSView-backed player to avoid the VideoPlayerView demangling crash
                        AVPlayerContainerView(player: player)
                            .frame(width: targetWidth, height: targetHeight)
                            .onAppear {
                                print("🎬 Video player appeared - ready to play")
                            }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.067, green: 0.094, blue: 0.153))
                }
            } else {
                // Loading placeholder
                ZStack {
                    Color(red: 0.067, green: 0.094, blue: 0.153)

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)

                        Text("Loading video...")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))

                        Text(viewModel.recording.filename)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
    }
}

// MARK: - Preview

private extension PreviewDialogView {
    var videoAspectRatio: CGFloat {
        viewModel.recording.aspectRatio
    }
}

// MARK: - NSView-backed player

/// Minimal wrapper around `AVPlayerView` to avoid `VideoPlayerView` demangling crashes.
///
/// SwiftUI's `VideoPlayer` (and its underlying `VideoPlayerView`) has known issues on macOS 14.x and 15.x
/// where, in certain build configurations (especially Release builds or when using LTO), the app can crash
/// due to symbol demangling errors. See: https://developer.apple.com/forums/thread/733834
/// This wrapper uses an `NSViewRepresentable` to embed an `AVPlayerView` directly, avoiding the problematic
/// SwiftUI component and ensuring stable video playback.
struct AVPlayerContainerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .floating
        view.showsFullScreenToggleButton = true
        view.videoGravity = .resizeAspect
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}
