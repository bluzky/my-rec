import SwiftUI

/// The main view for region selection overlay
private enum RegionSelectionCoordinateSpace {
    static let overlay = "RegionSelectionOverlay"
}

struct RegionSelectionView: View {
    @ObservedObject var viewModel: RegionSelectionViewModel
    let onClose: () -> Void

    @State private var showCountdown = false
    @State private var overlayOpacity: Double = 0.0

    init(viewModel: RegionSelectionViewModel, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // Default: show full screen bounds when no window hover and no selection
            if !viewModel.isHoveringOverWindow && viewModel.selectedRegion == nil {
                let fullScreenSwiftUI = convertScreenToSwiftUICoordinates(viewModel.screenBounds)

                // Dimming overlay outside full screen
                DimmingOverlay(cutoutRegion: fullScreenSwiftUI, opacity: overlayOpacity)

                // Full screen bounding box (like window hover)
                FullScreenBoundingBox(bounds: fullScreenSwiftUI)
            }

            // Window hover highlight
            if viewModel.isHoveringOverWindow, let window = viewModel.hoveredWindow {
                // Window bounds are in screen coordinates, convert to SwiftUI coordinates for display
                let swiftUIBounds = convertScreenToSwiftUICoordinates(window.bounds)

                // Dimming overlay outside hovered window
                DimmingOverlay(cutoutRegion: swiftUIBounds, opacity: overlayOpacity)

                WindowHighlightOverlay(window: window, bounds: swiftUIBounds)
            }

            // Selection area (if region exists)
            if let screenRegion = viewModel.selectedRegion {
                let swiftUIRegion = convertScreenToSwiftUICoordinates(screenRegion)

                // Dimming overlay outside selection
                DimmingOverlay(cutoutRegion: swiftUIRegion, opacity: overlayOpacity)

                SelectionOverlay(region: swiftUIRegion, viewModel: viewModel)
            }

            // Settings bar at the bottom center (macOS native style)
            VStack {
                Spacer()
                SettingsBarView(
                    settingsManager: SettingsManager.shared,
                    regionSize: viewModel.selectedRegion?.size ?? viewModel.screenBounds.size,
                    onClose: {
                        self.viewModel.reset()
                        self.onClose()
                    },
                    onRecord: {
                        self.handleRecordButton()
                    },
                    isRecording: false // TODO: Hook up actual recording state
                )
                .fixedSize(horizontal: true, vertical: true) // Fit content size
                .frame(maxWidth: .infinity) // Center horizontally
                .padding(.bottom, 40)
            }
            .opacity(showCountdown ? 0 : 1) // Hide settings bar during countdown

            // Countdown overlay
            if showCountdown {
                CountdownOverlay {
                    handleCountdownComplete()
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: RegionSelectionCoordinateSpace.overlay)
        .onAppear {
            // Fade in the overlay
            withAnimation(.easeOut(duration: 0.3)) {
                overlayOpacity = 1.0
            }
        }
        .onHover { isHovering in
            if !isHovering {
                viewModel.clearWindowHover()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow starting a new drag when no region is selected
                    // Once dragging has started (isDragging = true), allow it to continue
                    if !viewModel.isDragging && viewModel.selectedRegion != nil {
                        return
                    }

                    // Clear window hover when dragging starts
                    if !viewModel.isDragging {
                        viewModel.clearWindowHover()
                    }
                    // Only handle drag if not resizing
                    if !viewModel.isResizing {
                        viewModel.handleDragChanged(value)
                    }
                }
                .onEnded { value in
                    if !viewModel.isResizing && viewModel.isDragging {
                        viewModel.handleDragEnded(value)
                    }
                }
        )
        .onTapGesture(perform: {
            // Only allow tap actions when no region is selected
            guard self.viewModel.selectedRegion == nil else { return }

            // Check if tapping on a hovered window
            if self.viewModel.isHoveringOverWindow {
                self.viewModel.selectHoveredWindow()
            } else {
                // If no selection and no window hover, clicking selects the full screen
                self.viewModel.selectedRegion = self.viewModel.screenBounds
            }
        })
        // Note: Escape key handling will be added at the window level for macOS 12 compatibility
    }

    /// Handle the record button action
    private func handleRecordButton() {
        // If no explicit selection, use full screen
        if viewModel.selectedRegion == nil {
            viewModel.selectedRegion = viewModel.screenBounds
        }

        print("🎬 Starting countdown before recording")
        // Show countdown overlay
        withAnimation(.easeInOut(duration: 0.3)) {
            showCountdown = true
        }
    }

    /// Handle countdown completion
    private func handleCountdownComplete() {
        guard let selectedRegion = viewModel.selectedRegion else {
            print("⚠️ No region selected")
            return
        }

        print("🎬 Countdown complete - starting recording with region: \(selectedRegion)")

        // Trigger recording state change
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.recording(startTime: Date())
        )

        // Close the region selection window
        onClose()
    }

    /// Convert global screen coordinates to the SwiftUI overlay coordinate space
    private func convertScreenToSwiftUICoordinates(_ screenRect: CGRect) -> CGRect {
        let bounds = viewModel.screenBounds

        return CGRect(
            x: screenRect.origin.x - bounds.origin.x,
            y: bounds.maxY - screenRect.origin.y - screenRect.height,
            width: screenRect.width,
            height: screenRect.height
        )
    }
}

/// The selection overlay showing the selected region with resize handles
struct SelectionOverlay: View {
    let region: CGRect
    @ObservedObject var viewModel: RegionSelectionViewModel

    var body: some View {
        ZStack {
            // Selection border - bright blue for better contrast
            Rectangle()
                .stroke(Color.blue.opacity(0.8), lineWidth: 3)
                .frame(width: region.width, height: region.height)
                .position(x: region.midX, y: region.midY)

            // Dimension label
            DimensionLabel(width: region.width, height: region.height)
                .position(x: region.midX, y: region.minY - 30)

            // 8 Resize handles
            ForEach(ResizeHandle.allCases, id: \.self) { handle in
                ResizeHandleView(
                    handle: handle,
                    onDragChanged: { value in
                        viewModel.handleResize(handle, dragValue: value)
                    },
                    onDragEnded: { value in
                        viewModel.handleResizeEnded(handle, dragValue: value)
                    },
                    coordinateSpaceName: RegionSelectionCoordinateSpace.overlay
                )
                .position(handle.position(in: region))
            }
        }
    }
}

// Make ResizeHandle conform to Hashable for ForEach
extension ResizeHandle: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .topLeft: hasher.combine(0)
        case .topCenter: hasher.combine(1)
        case .topRight: hasher.combine(2)
        case .middleLeft: hasher.combine(3)
        case .middleRight: hasher.combine(4)
        case .bottomLeft: hasher.combine(5)
        case .bottomCenter: hasher.combine(6)
        case .bottomRight: hasher.combine(7)
        }
    }
}

/// Dimming overlay that dims everything except the cutout region
struct DimmingOverlay: View {
    let cutoutRegion: CGRect
    let opacity: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top rectangle (above selection)
                Rectangle()
                    .fill(Color.black.opacity(0.3 * opacity))
                    .frame(width: geometry.size.width, height: cutoutRegion.minY)
                    .position(x: geometry.size.width / 2, y: cutoutRegion.minY / 2)

                // Bottom rectangle (below selection)
                Rectangle()
                    .fill(Color.black.opacity(0.3 * opacity))
                    .frame(width: geometry.size.width, height: geometry.size.height - cutoutRegion.maxY)
                    .position(x: geometry.size.width / 2, y: cutoutRegion.maxY + (geometry.size.height - cutoutRegion.maxY) / 2)

                // Left rectangle (left of selection)
                Rectangle()
                    .fill(Color.black.opacity(0.3 * opacity))
                    .frame(width: cutoutRegion.minX, height: cutoutRegion.height)
                    .position(x: cutoutRegion.minX / 2, y: cutoutRegion.midY)

                // Right rectangle (right of selection)
                Rectangle()
                    .fill(Color.black.opacity(0.3 * opacity))
                    .frame(width: geometry.size.width - cutoutRegion.maxX, height: cutoutRegion.height)
                    .position(x: cutoutRegion.maxX + (geometry.size.width - cutoutRegion.maxX) / 2, y: cutoutRegion.midY)
            }
        }
        .ignoresSafeArea()
    }
}

/// Label showing the dimensions of the selected region
struct DimensionLabel: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Text("\(Int(width)) × \(Int(height))")
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.75))
            )
    }
}

/// Full screen bounding box (default state)
struct FullScreenBoundingBox: View {
    let bounds: CGRect

    var body: some View {
        Rectangle()
            .stroke(Color.green, lineWidth: 3)
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
    }
}

/// Overlay that highlights a window when hovering
struct WindowHighlightOverlay: View {
    let window: WindowInfo
    let bounds: CGRect

    var body: some View {
        // Just show the window boundary
        Rectangle()
            .stroke(Color.green, lineWidth: 3)
            .frame(width: bounds.width, height: bounds.height)
            .position(x: bounds.midX, y: bounds.midY)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct RegionSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = RegionSelectionViewModel(
            screenBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        // Set a sample region for preview
        viewModel.selectedRegion = CGRect(x: 400, y: 300, width: 800, height: 600)

        return RegionSelectionView(viewModel: viewModel) { }
            .frame(width: 1920, height: 1080)
    }
}
#endif
