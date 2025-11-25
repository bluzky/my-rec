//
//  HomePageView.swift
//  MyRec
//
//  Main home page with record button and recent recordings
//

import SwiftUI

struct HomePageView: View {
    @StateObject private var viewModel = HomePageViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Record Screen button
            recordButtonSection
                .padding(.top, 32)
                .padding(.bottom, 24)

            Divider()

            // Recent recordings list
            if viewModel.recentRecordings.isEmpty {
                emptyStateView
            } else {
                recordingsListView
            }
        }
        .frame(minWidth: 480, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.openRecordingDirectory() }) {
                    Image(systemName: "folder")
                }
                .help("Open Recording Directory")
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { viewModel.openSettings() }) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
    }

    // MARK: - Record Button Section

    private var recordButtonSection: some View {
        RecordButton(action: { viewModel.startRecording() })
    }

    // MARK: - Recordings List

    private var recordingsListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.recentRecordings) { recording in
                    HomeRecordingRowView(
                        recording: recording,
                        onPlay: { viewModel.playRecording(recording) },
                        onTrim: { viewModel.trimRecording(recording) },
                        onDelete: { viewModel.deleteRecording(recording) },
                        onShare: { viewModel.shareRecording(recording) }
                    )

                    if recording.id != viewModel.recentRecordings.last?.id {
                        Divider()
                            .padding(.horizontal, 24)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Recordings Yet")
                .font(.title3)
                .fontWeight(.medium)

            Text("Click the button above to start your first recording")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Record Button with Hover Effect

struct RecordButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack {
            Spacer()

            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isHovering ? 1.05 : 1.0)

                    Image(systemName: "video.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .shadow(color: Color.red.opacity(isHovering ? 0.6 : 0.4), radius: isHovering ? 16 : 12, x: 0, y: 4)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }

            Spacer()
        }
    }
}

// MARK: - Home Recording Row View

struct HomeRecordingRowView: View {
    let recording: VideoMetadata
    let onPlay: () -> Void
    let onTrim: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail
            ZStack {
                if let thumbnail = recording.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 80)
                        .clipped()
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                } else {
                    // Fallback placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(recording.thumbnailColor.opacity(0.2))
                        .frame(width: 120, height: 80)
                }

                // Play button overlay
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 28, height: 28)
                            .blur(radius: 1)
                    )
            }
            .onTapGesture(perform: onPlay)

            // Recording info
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(recording.filename)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                }

                Text("\(recording.formattedDuration) • \(recording.formattedFileSize) • \(recording.displayResolution)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Action buttons (always visible)
                HStack(spacing: 12) {
                    ActionIconButton(icon: "scissors", action: onTrim)
                    ActionIconButton(icon: "folder", action: {
                        NSWorkspace.shared.activateFileViewerSelecting([recording.fileURL])
                    })
                    ActionIconButton(icon: "trash", action: onDelete, hoverColor: .red)
                    ActionIconButton(icon: "square.and.arrow.up", action: onShare)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

}

// MARK: - Action Icon Button

struct ActionIconButton: View {
    let icon: String
    let action: () -> Void
    var color: Color = .secondary
    var hoverColor: Color? = nil

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(isHovering && hoverColor != nil ? hoverColor! : color)
                .frame(width: 32, height: 32)
                .background(isHovering ? Color(NSColor.controlBackgroundColor).opacity(0.5) : Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Preview
