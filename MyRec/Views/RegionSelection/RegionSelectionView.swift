import SwiftUI

/// The main view for region selection overlay
struct RegionSelectionView: View {
    @ObservedObject var viewModel: RegionSelectionViewModel

    var body: some View {
        ZStack {
            // Semi-transparent dark overlay
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)

            // Selection area (if region exists)
            if let region = viewModel.selectedRegion {
                SelectionOverlay(region: region)
            }

            // Instructions text (shown when no selection)
            if viewModel.selectedRegion == nil && !viewModel.isDragging {
                InstructionsView()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    viewModel.handleDragChanged(value)
                }
                .onEnded { value in
                    viewModel.handleDragEnded(value)
                }
        )
    }
}

/// Instructions shown when no selection is made
struct InstructionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.draw")
                .font(.system(size: 48))
                .foregroundColor(.white)

            Text("Click and drag to select a region")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            Text("Press ESC to cancel")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
        )
    }
}

/// The selection overlay showing the selected region
struct SelectionOverlay: View {
    let region: CGRect

    var body: some View {
        ZStack {
            // Clear area where selection is made
            Rectangle()
                .fill(Color.clear)
                .frame(width: region.width, height: region.height)
                .position(x: region.midX, y: region.midY)
                .border(Color.blue, width: 2)

            // Dimension label
            DimensionLabel(width: region.width, height: region.height)
                .position(x: region.midX, y: region.minY - 30)
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

// MARK: - Preview Provider

#if DEBUG
struct RegionSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = RegionSelectionViewModel(
            screenBounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        // Set a sample region for preview
        viewModel.selectedRegion = CGRect(x: 400, y: 300, width: 800, height: 600)

        return RegionSelectionView(viewModel: viewModel)
            .frame(width: 1920, height: 1080)
    }
}
#endif
