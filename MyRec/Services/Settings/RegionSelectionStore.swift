import Foundation
import CoreGraphics

/// Stores the most recent selection so we can restore manual regions between sessions.
struct RegionSelectionSnapshot: Codable {
    let mode: SelectionMode
    let region: CodableCGRect?
}

/// Codable wrapper for CGRect since UserDefaults doesn't support it directly.
struct CodableCGRect: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        self.x = rect.origin.x.doubleValue
        self.y = rect.origin.y.doubleValue
        self.width = rect.width.doubleValue
        self.height = rect.height.doubleValue
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

private extension CGFloat {
    var doubleValue: Double { Double(self) }
}

final class RegionSelectionStore {
    static let shared = RegionSelectionStore()

    private let defaults: UserDefaults
    private let lastSelectionKey = "lastRegionSelection"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Persist the last used selection mode and region.
    func save(selectionMode: SelectionMode, region: CGRect?) {
        let snapshot = RegionSelectionSnapshot(
            mode: selectionMode,
            region: region.map(CodableCGRect.init)
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: lastSelectionKey)
    }

    /// Return the last manual region if manual mode was the most recent selection.
    func lastManualRegion() -> CGRect? {
        guard let data = defaults.data(forKey: lastSelectionKey),
              let snapshot = try? JSONDecoder().decode(RegionSelectionSnapshot.self, from: data),
              snapshot.mode == .region,
              let region = snapshot.region else {
            return nil
        }

        return region.rect
    }

    func clear() {
        defaults.removeObject(forKey: lastSelectionKey)
    }
}
