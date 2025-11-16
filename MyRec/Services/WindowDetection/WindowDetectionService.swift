import AppKit
import CoreGraphics

/// Service for detecting and getting information about windows on screen
public class WindowDetectionService {
    public static let shared = WindowDetectionService()

    private init() {}

    /// Get window information at a specific point
    public func getWindowAt(point: CGPoint) -> WindowInfo? {
        // Determine the full screen bounds for coordinate conversion (origin bottom-left)
        let screenBounds = WindowDetectionService.globalScreenBounds

        // Get window list ordered from front to back
        guard let windowList = CGWindowListCopyWindowInfo(
            .optionOnScreenOnly,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        // Iterate through windows to find one at the given point
        for windowDict in windowList {
            // Skip invisible, offscreen, or menu bar windows
            guard let bounds = windowDict[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  let layer = windowDict[kCGWindowLayer as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let windowNumber = windowDict[kCGWindowNumber as String] as? Int else {
                continue
            }

            // Skip system windows, menu bar, dock, etc.
            if layer != 0 || ownerName == "Window Server" || ownerName == "Dock" {
                continue
            }

            let windowRect = WindowDetectionService.convertToAppKitRect(
                x: x,
                y: y,
                width: width,
                height: height,
                screenBounds: screenBounds
            )

            // Check if point is within window bounds
            if windowRect.contains(point) {
                let windowTitle = windowDict[kCGWindowName as String] as? String ?? ""

                return WindowInfo(
                    windowNumber: windowNumber,
                    bounds: windowRect,
                    title: windowTitle,
                    ownerName: ownerName,
                    layer: layer
                )
            }
        }

        return nil
    }

    /// Get all visible windows (excluding system windows)
    public func getAllVisibleWindows() -> [WindowInfo] {
        let screenBounds = WindowDetectionService.globalScreenBounds

        guard let windowList = CGWindowListCopyWindowInfo(
            .optionOnScreenOnly,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var windows: [WindowInfo] = []

        for windowDict in windowList {
            guard let bounds = windowDict[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? CGFloat,
                  let y = bounds["Y"] as? CGFloat,
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  let layer = windowDict[kCGWindowLayer as String] as? Int,
                  let ownerName = windowDict[kCGWindowOwnerName as String] as? String,
                  let windowNumber = windowDict[kCGWindowNumber as String] as? Int else {
                continue
            }

            // Skip system windows
            if layer != 0 || ownerName == "Window Server" || ownerName == "Dock" || ownerName == "SystemUIServer" {
                continue
            }

            let windowRect = WindowDetectionService.convertToAppKitRect(
                x: x,
                y: y,
                width: width,
                height: height,
                screenBounds: screenBounds
            )
            let windowTitle = windowDict[kCGWindowName as String] as? String ?? ""

            windows.append(WindowInfo(
                windowNumber: windowNumber,
                bounds: windowRect,
                title: windowTitle,
                ownerName: ownerName,
                layer: layer
            ))
        }

        // Sort by layer (frontmost first)
        windows.sort { $0.layer < $1.layer }
        return windows
    }
}

private extension WindowDetectionService {
    private static var globalScreenBounds: CGRect {
        NSScreen.screens.reduce(into: CGRect.null) { union, screen in
            if union.isNull {
                union = screen.frame
            } else {
                union = union.union(screen.frame)
            }
        }
    }

    private static func convertToAppKitRect(
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        screenBounds: CGRect
    ) -> CGRect {
        return CGRect(
            x: x,
            y: screenBounds.maxY - y - height,
            width: width,
            height: height
        )
    }
}

/// Information about a detected window
public struct WindowInfo {
    public let windowNumber: Int
    public let bounds: CGRect
    public let title: String
    public let ownerName: String
    public let layer: Int

    /// User-friendly display name
    public var displayName: String {
        if title.isEmpty {
            return ownerName
        }
        return "\(title) - \(ownerName)"
    }

    /// Check if this window is likely a user window (not system)
    public var isUserWindow: Bool {
        return layer == 0 &&
               ownerName != "Window Server" &&
               ownerName != "Dock" &&
               ownerName != "SystemUIServer" &&
               ownerName != "SystemUIServer.main" &&
               !bounds.isEmpty
    }
}
