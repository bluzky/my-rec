import SwiftUI

/// A draggable resize handle with hover effects and cursor changes
struct ResizeHandleView: View {
    let handle: ResizeHandle
    let onDragChanged: (DragGesture.Value) -> Void
    let onDragEnded: (DragGesture.Value) -> Void
    let coordinateSpaceName: String

    @State private var isHovering = false
    @State private var isDragging = false

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .scaleEffect(isHovering || isDragging ? 1.3 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(coordinateSpaceName))
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                        }
                        onDragChanged(value)
                    }
                    .onEnded { value in
                        isDragging = false
                        onDragEnded(value)
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    handle.cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

#if DEBUG
struct ResizeHandleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ResizeHandleView(
                handle: .topLeft,
                onDragChanged: { _ in },
                onDragEnded: { _ in },
                coordinateSpaceName: "PreviewSpace"
            )
            .frame(width: 50, height: 50)

            ResizeHandleView(
                handle: .middleRight,
                onDragChanged: { _ in },
                onDragEnded: { _ in },
                coordinateSpaceName: "PreviewSpace"
            )
            .frame(width: 50, height: 50)
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .coordinateSpace(name: "PreviewSpace")
    }
}
#endif
