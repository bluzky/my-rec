import SwiftUI

/// The main view for region selection overlay
private enum RegionSelectionCoordinateSpace {
    static let overlay = "RegionSelectionOverlay"
}

struct RegionSelectionView: View {
    @ObservedObject var viewModel: RegionSelectionViewModel
    let onClose: () -> Void

    @State private var showCountdown = false
    @State private var isRecording = false
    @State private var overlayOpacity: Double = 0.0

    init(viewModel: RegionSelectionViewModel, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // Overlay content (default box, window hover, or selection)
            RegionOverlayContent(
                viewModel: viewModel,
                overlayOpacity: isRecording ? 0.0 : overlayOpacity,
                showHandles: !showCountdown && !isRecording,
                showDimensionLabel: !isRecording,
                convertToSwiftUI: convertScreenToSwiftUICoordinates
            )

            // Crosshair guide at current cursor position
            if !isRecording && viewModel.selectionMode != .screen {
                if viewModel.isResizing,
                   let handle = viewModel.activeResizeHandle,
                   let selectedRegion = viewModel.selectedRegion {
                    let swiftUIRegion = convertScreenToSwiftUICoordinates(selectedRegion)
                    if handle.isCorner {
                        let cornerPoint = handle.position(in: swiftUIRegion)
                        CrosshairGuideView(position: cornerPoint)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    } else if handle.isEdge {
                        HairlineGuideView(region: swiftUIRegion, handle: handle)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                } else if viewModel.selectionMode == .region &&
                            (viewModel.selectedRegion == nil || viewModel.isDragging),
                          let cursorLocation = viewModel.cursorLocation {
                    CrosshairGuideView(position: convertScreenPointToSwiftUICoordinates(cursorLocation))
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }

            // Settings bar at the bottom center
            if !showCountdown && !isRecording {
                SettingsBarContainer(
                    viewModel: viewModel,
                    onClose: {
                        self.viewModel.reset()
                        self.onClose()
                    },
                    onRecord: handleRecordButton
                )
                .transition(.opacity)
            }

            // Countdown overlay - positioned at center of selected region
            if showCountdown, let selectedRegion = viewModel.selectedRegion {
                let swiftUIRegion = convertScreenToSwiftUICoordinates(selectedRegion)
                CountdownOverlay {
                    handleCountdownComplete()
                }
                .position(x: swiftUIRegion.midX, y: swiftUIRegion.midY)
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
        .onReceive(NotificationCenter.default.publisher(for: .recordingFinished)) { _ in
            // Close window when recording finishes
            print("📹 Recording finished - closing overlay window")
            self.viewModel.isRecording = false
            self.viewModel.reset()
            self.onClose()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cancelCountdown)) { _ in
            // Cancel countdown and return to selection mode
            print("❌ Countdown canceled - returning to selection mode")
            withAnimation(.easeInOut(duration: 0.2)) {
                showCountdown = false
            }
        }
        .modifier(RegionSelectionGestureModifier(viewModel: viewModel))
        // Note: Escape key handling will be added at the window level for macOS 12 compatibility
    }

    /// Handle the record button action
    private func handleRecordButton() {
        // If no explicit selection, use full screen
        if viewModel.selectedRegion == nil {
            viewModel.selectedRegion = viewModel.screenBounds
        }

        print("🎬 Starting countdown before recording")

        // Notify that countdown has started (to show control bar)
        NotificationCenter.default.post(
            name: .countdownStarted,
            object: nil,
            userInfo: [NotificationUserInfoKey.selectedRegion: viewModel.selectedRegion as Any]
        )

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

        // Hide countdown, enter recording mode
        showCountdown = false
        isRecording = true
        viewModel.isRecording = true  // Update view model to disable window detection
        viewModel.clearWindowHover()  // Clear any window hover state

        // Trigger recording state change with region info
        NotificationCenter.default.post(
            name: .recordingStateChanged,
            object: RecordingState.recording(startTime: Date()),
            userInfo: [NotificationUserInfoKey.selectedRegion: selectedRegion]
        )

        // Keep window open during recording to show selection border
        print("📹 Recording in progress - keeping overlay visible with border only")
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

    /// Convert a global screen point to the SwiftUI overlay coordinate space
    private func convertScreenPointToSwiftUICoordinates(_ screenPoint: CGPoint) -> CGPoint {
        let bounds = viewModel.screenBounds

        return CGPoint(
            x: screenPoint.x - bounds.origin.x,
            y: bounds.maxY - screenPoint.y
        )
    }
}

/// The selection overlay showing the selected region with resize handles
struct SelectionOverlay: View {
    let region: CGRect
    @ObservedObject var viewModel: RegionSelectionViewModel
    let showHandles: Bool
    let showDimensionLabel: Bool

    var body: some View {
        ZStack {
            // Selection border - bright blue for better contrast
            // Outset by half the line width so border is entirely outside the region
            let borderWidth: CGFloat = 3
            Rectangle()
                .stroke(Color.blue.opacity(0.8), lineWidth: borderWidth)
                .frame(width: region.width + borderWidth, height: region.height + borderWidth)
                .position(x: region.midX, y: region.midY)

            // Dimension label - hide during recording
            if showDimensionLabel {
                DimensionLabel(width: region.width, height: region.height)
                    .position(x: region.midX, y: region.minY - 30)
            }

            // 8 Resize handles - only show when not recording
            if showHandles {
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
}

/// Crosshair guide rendered at the current cursor position
struct CrosshairGuideView: View {
    let position: CGPoint

    var body: some View {
        GeometryReader { geometry in
            // Clamp to view bounds to avoid drawing outside the overlay
            let clampedX = min(max(position.x, 0), geometry.size.width)
            let clampedY = min(max(position.y, 0), geometry.size.height)

            Path { path in
                // Vertical line
                path.move(to: CGPoint(x: clampedX, y: 0))
                path.addLine(to: CGPoint(x: clampedX, y: geometry.size.height))

                // Horizontal line
                path.move(to: CGPoint(x: 0, y: clampedY))
                path.addLine(to: CGPoint(x: geometry.size.width, y: clampedY))
            }
            .stroke(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
            .overlay(
                Circle()
                    .stroke(Color.blue.opacity(0.9), lineWidth: 1)
                    .background(
                        Circle()
                            .fill(Color.blue.opacity(0.35))
                    )
                    .frame(width: 8, height: 8)
                    .position(x: clampedX, y: clampedY)
            )
        }
    }
}

/// Single hairline guide shown when dragging an edge handle
struct HairlineGuideView: View {
    let region: CGRect
    let handle: ResizeHandle

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                switch handle {
                case .middleLeft, .middleRight:
                    let x = handle == .middleLeft ? region.minX : region.maxX
                    let clampedX = min(max(x, 0), geometry.size.width)
                    path.move(to: CGPoint(x: clampedX, y: 0))
                    path.addLine(to: CGPoint(x: clampedX, y: geometry.size.height))
                case .topCenter, .bottomCenter:
                    let y = handle == .topCenter ? region.minY : region.maxY
                    let clampedY = min(max(y, 0), geometry.size.height)
                    path.move(to: CGPoint(x: 0, y: clampedY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: clampedY))
                default:
                    break
                }
            }
            .stroke(Color.blue.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
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
/// Uses even-odd fill rule for better performance
struct DimmingOverlay: View {
    let cutoutRegion: CGRect
    let opacity: Double

    var body: some View {
        GeometryReader { geometry in
            DimmingShape(cutoutRegion: cutoutRegion)
                .fill(Color.black.opacity(0.3 * opacity), style: FillStyle(eoFill: true))
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }
}

/// Shape that creates a full-screen rectangle with a cutout region using even-odd fill
private struct DimmingShape: Shape {
    let cutoutRegion: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Add the full screen rectangle (outer)
        path.addRect(rect)

        // Add the cutout region (inner) - this will be "cut out" with even-odd fill
        path.addRect(cutoutRegion)

        return path
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

// MARK: - Extracted Subviews

/// Renders the appropriate overlay content based on current state
struct RegionOverlayContent: View {
    @ObservedObject var viewModel: RegionSelectionViewModel
    let overlayOpacity: Double
    let showHandles: Bool
    let showDimensionLabel: Bool
    let convertToSwiftUI: (CGRect) -> CGRect

    var body: some View {
        Group {
            // Default: show full screen bounds when no window hover and no selection
            if !viewModel.isHoveringOverWindow && viewModel.selectedRegion == nil {
                let fullScreenSwiftUI = convertToSwiftUI(viewModel.screenBounds)

                DimmingOverlay(cutoutRegion: fullScreenSwiftUI, opacity: overlayOpacity)
                FullScreenBoundingBox(bounds: fullScreenSwiftUI)
            }

            // Window hover highlight
            if viewModel.isHoveringOverWindow, let window = viewModel.hoveredWindow {
                let swiftUIBounds = convertToSwiftUI(window.bounds)

                DimmingOverlay(cutoutRegion: swiftUIBounds, opacity: overlayOpacity)
                WindowHighlightOverlay(window: window, bounds: swiftUIBounds)
            }

            // Selection area (if region exists)
            if let screenRegion = viewModel.selectedRegion {
                let swiftUIRegion = convertToSwiftUI(screenRegion)

                DimmingOverlay(cutoutRegion: swiftUIRegion, opacity: overlayOpacity)
                SelectionOverlay(region: swiftUIRegion, viewModel: viewModel, showHandles: showHandles, showDimensionLabel: showDimensionLabel)
            }
        }
    }
}

/// Container for the settings bar with proper layout
struct SettingsBarContainer: View {
    @ObservedObject var viewModel: RegionSelectionViewModel
    let onClose: () -> Void
    let onRecord: () -> Void

    @State private var savedPosition: CGSize = .zero
    @State private var currentDragOffset: CGSize = .zero
    @State private var isDragging: Bool = false

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                SettingsBarView(
                    settingsManager: SettingsManager.shared,
                    viewModel: viewModel,
                    regionSize: viewModel.selectedRegion?.size ?? viewModel.screenBounds.size,
                    onClose: onClose,
                    onRecord: onRecord,
                    isRecording: false // TODO: Hook up actual recording state
                )
                .fixedSize(horizontal: true, vertical: true)
            }
            .compositingGroup() // Render view and shadow together as one unit
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
            .offset(
                x: savedPosition.width + currentDragOffset.width,
                y: savedPosition.height + currentDragOffset.height
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        currentDragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false
                        // Save the final position
                        savedPosition = CGSize(
                            width: savedPosition.width + value.translation.width,
                            height: savedPosition.height + value.translation.height
                        )
                        currentDragOffset = .zero
                    }
            )
        }
        .allowsHitTesting(true)
    }
}

/// Gesture modifier for drag and tap interactions
struct RegionSelectionGestureModifier: ViewModifier {
    @ObservedObject var viewModel: RegionSelectionViewModel

    func body(content: Content) -> some View {
        content
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
            .onTapGesture {
                // Only allow tap actions when no region is selected
                guard viewModel.selectedRegion == nil else { return }

                // Check if tapping on a hovered window (works in both window and region mode)
                if viewModel.isHoveringOverWindow {
                    viewModel.selectHoveredWindow()
                } else if viewModel.selectionMode == .screen {
                    // In screen mode only: clicking selects the full screen
                    viewModel.selectedRegion = viewModel.screenBounds
                }
                // In region mode: clicking on empty space does nothing (user must drag)
            }
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
