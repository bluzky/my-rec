import AppKit

/// Represents the 8 resize handles for the region selection rectangle
enum ResizeHandle: CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, middleRight
    case bottomLeft, bottomCenter, bottomRight

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return true
        default:
            return false
        }
    }

    var isEdge: Bool {
        return !isCorner
    }

    /// The appropriate cursor for each resize handle
    var cursor: NSCursor {
        switch self {
        case .topLeft, .bottomRight:
            return .pointingHand // macOS lacks diagonal resize cursors; use best available
        case .topRight, .bottomLeft:
            return .pointingHand
        case .topCenter, .bottomCenter:
            return .resizeUpDown
        case .middleLeft, .middleRight:
            return .resizeLeftRight
        }
    }

    /// Position offset for the handle relative to the region
    func position(in region: CGRect) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: region.minX, y: region.minY)
        case .topCenter:
            return CGPoint(x: region.midX, y: region.minY)
        case .topRight:
            return CGPoint(x: region.maxX, y: region.minY)
        case .middleLeft:
            return CGPoint(x: region.minX, y: region.midY)
        case .middleRight:
            return CGPoint(x: region.maxX, y: region.midY)
        case .bottomLeft:
            return CGPoint(x: region.minX, y: region.maxY)
        case .bottomCenter:
            return CGPoint(x: region.midX, y: region.maxY)
        case .bottomRight:
            return CGPoint(x: region.maxX, y: region.maxY)
        }
    }
}
