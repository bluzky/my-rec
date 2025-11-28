import SwiftUI

extension View {
    /// Apply a terminal-style monospaced font as the app-wide default.
    func applyMonoFont() -> some View {
        environment(\.font, .system(.body, design: .monospaced))
    }
}
