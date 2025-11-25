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
                        VideoPlayer(player: player)
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
