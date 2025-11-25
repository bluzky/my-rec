//
//  FloatingRecordingControlView.swift
//  MyRec
//
//  Floating control panel shown during recording
//

import SwiftUI

struct FloatingRecordingControlView: View {
    @ObservedObject var viewModel: FloatingRecordingControlViewModel

    @State private var isHoveringPause = false
    @State private var isHoveringStop = false
    @State private var isHoveringHandle = false

    var body: some View {
        HStack(spacing: 0) {
            // Toggle handle (only visible when inside recording region)
            if viewModel.shouldShowCollapsible {
                toggleHandle
            }

            // Main control content (collapsible only when inside recording region)
            if !viewModel.shouldShowCollapsible || !viewModel.isCollapsed {
                HStack(spacing: 8) {
                    // Elapsed time display with recording dot
                    timeDisplay
                        .padding(.leading, 4)

                    Divider()
                        .frame(height: 30)
                        .padding(.horizontal, 4)

                    // Pause button
                    pauseButton

                    // Stop button
                    stopButton
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(
            Group {
                if !viewModel.isCollapsed || !viewModel.shouldShowCollapsible {
                    VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
                        .cornerRadius(12)
                }
            }
        )
        .overlay(
            Group {
                if !viewModel.isCollapsed || !viewModel.shouldShowCollapsible {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
            }
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .onChange(of: viewModel.shouldShowCollapsible) { shouldShow in
            if !shouldShow {
                // Reset when not inside recording region
                viewModel.isCollapsed = false
            }
            // Note: No auto-collapse - starts visible by default
        }
    }

    // MARK: - Toggle Handle

    private var toggleHandle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isCollapsed.toggle()
            }
        }) {
            ZStack {
                // Background with left-rounded corners
                LeftRoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))

                // Chevron icon
                Image(systemName: viewModel.isCollapsed ? "chevron.left" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(isHoveringHandle ? 0.9 : 0.6))
            }
            .frame(width: 24, height: 60)
            .overlay(
                LeftRoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .help(viewModel.isCollapsed ? "Show Controls" : "Hide Controls")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringHandle = hovering
            }
        }
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        HStack(spacing: 10) {
            // Recording indicator dot
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.orange)
                .frame(width: 8, height: 8)
                .opacity(viewModel.isPaused ? 0.5 : 1.0)
                .animation(
                    viewModel.isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .none,
                    value: viewModel.isPaused ? 0 : 1
                )

            // Time text or ready indicator
            if viewModel.isRecording {
                Text(viewModel.formattedElapsedTime)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(minWidth: 70, alignment: .leading)
            } else {
                Text("Ready")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                    .frame(minWidth: 70, alignment: .leading)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Pause Button

    private var pauseButton: some View {
        Button(action: {
            viewModel.togglePause()
        }) {
            Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                .font(.system(size: 18))
                .foregroundColor(.primary.opacity(viewModel.isRecording ? (isHoveringPause ? 0.9 : 0.7) : 0.3))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringPause && viewModel.isRecording ? Color.primary.opacity(0.15) : Color.clear)
                )
                .scaleEffect(isHoveringPause && viewModel.isRecording ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringPause)
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isRecording)
        .help(viewModel.isPaused ? "Resume Recording" : "Pause Recording")
        .onHover { hovering in
            isHoveringPause = hovering && viewModel.isRecording
        }
    }

    // MARK: - Stop Button

    private var stopButton: some View {
        Button(action: {
            viewModel.cancelOrStopRecording()
        }) {
            Image(systemName: "stop.fill")
                .font(.system(size: 18))
                .foregroundColor(.primary.opacity(isHoveringStop ? 0.9 : 0.7))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringStop ? Color.red.opacity(0.2) : Color.clear)
                )
                .scaleEffect(isHoveringStop ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: isHoveringStop)
        }
        .buttonStyle(.plain)
        .help(viewModel.isRecording ? "Stop Recording" : "Cancel")
        .onHover { hovering in
            isHoveringStop = hovering
        }
    }
}

// MARK: - Left Rounded Rectangle Shape

/// Custom shape with rounded corners only on the left side
struct LeftRoundedRectangle: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start from top-left corner
        path.move(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))

        // Top edge (straight to right)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))

        // Right edge (straight down)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Bottom edge (straight to left, before corner)
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

        // Bottom-left corner (rounded)
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        // Left edge (straight up)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))

        // Top-left corner (rounded)
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        return path
    }
}

// MARK: - Preview

#if DEBUG
struct FloatingRecordingControlView_Previews: PreviewProvider {
    static var previews: some View {
        FloatingRecordingControlView(
            viewModel: FloatingRecordingControlViewModel()
        )
        .padding(40)
        .background(Color.gray.opacity(0.3))
    }
}
#endif
