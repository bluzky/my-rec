import SwiftUI

/// The main view for region selection overlay
private enum RegionSelectionCoordinateSpace {
    static let overlay = "RegionSelectionOverlay"
}

struct RegionSelectionView: View {
    @ObservedObject var viewModel: RegionSelectionViewModel
    let onClose: () -> Void

    init(viewModel: RegionSelectionViewModel, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            // Window hover highlight
            if viewModel.isHoveringOverWindow, let window = viewModel.hoveredWindow {
                // Window bounds are in screen coordinates, convert to SwiftUI coordinates for display
                let swiftUIBounds = convertScreenToSwiftUICoordinates(window.bounds)
                WindowHighlightOverlay(window: window, bounds: swiftUIBounds)
            }

            // Selection area (if region exists)
            if let screenRegion = viewModel.selectedRegion {
                let swiftUIRegion = convertScreenToSwiftUICoordinates(screenRegion)
                SelectionOverlay(region: swiftUIRegion, viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: RegionSelectionCoordinateSpace.overlay)
        .onHover { isHovering in
            if !isHovering {
                viewModel.clearWindowHover()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Clear window hover when dragging starts
                    if !viewModel.isDragging {
                        viewModel.clearWindowHover()
                    }
                    // Only handle drag if not resizing
                    if !viewModel.isResizing {
                        // If a region is already selected, don't create a new one on drag
                        // This allows users to see the resize handles instead of starting a new selection
                        if viewModel.selectedRegion == nil {
                            viewModel.handleDragChanged(value)
                        }
                    }
                }
                .onEnded { value in
                    if !viewModel.isResizing {
                        // Only handle drag end if we were creating a new selection
                        if viewModel.selectedRegion == nil {
                            viewModel.handleDragEnded(value)
                        }
                    }
                }
        )
        .onTapGesture(perform: {
            // Check if tapping on a hovered window
            if self.viewModel.isHoveringOverWindow {
                self.viewModel.selectHoveredWindow()
            } else {
                // If a region is already selected and we're not hovering over a window,
                // clear the selection to allow starting a new selection
                if self.viewModel.selectedRegion != nil {
                    self.viewModel.selectedRegion = nil
                }
            }
        })
        // Note: Escape key handling will be added at the window level for macOS 12 compatibility
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
            // Selection border - blue border only (no white outline)
            Rectangle()
                .stroke(Color.blue, lineWidth: 2)
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
