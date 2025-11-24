import SwiftUI
import Combine

/// Simple countdown overlay showing 3-2-1 before recording starts
/// Uses Combine Timer for reliable, drift-free countdown timing
struct CountdownOverlay: View {
    let onComplete: () -> Void

    @State private var startTime = Date()
    @State private var currentTime = Date()
    @State private var timerCancellable: AnyCancellable?

    var body: some View {
        let elapsed = currentTime.timeIntervalSince(startTime)
        let phase = countdownPhase(for: elapsed)

        ZStack {
            if phase.isVisible {
                CountdownNumberView(
                    number: phase.number,
                    progress: phase.progress
                )
            }
        }
        .onAppear {
            startTime = Date()
            currentTime = Date()
            startTimer()
        }
        .onDisappear {
            timerCancellable?.cancel()
        }
    }

    /// Start the timer for smooth updates
    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                currentTime = Date()
                let elapsed = currentTime.timeIntervalSince(startTime)
                if elapsed >= 3.2 {
                    timerCancellable?.cancel()
                    onComplete()
                }
            }
    }

    /// Determine the countdown phase based on elapsed time
    private func countdownPhase(for elapsed: TimeInterval) -> CountdownPhase {
        switch elapsed {
        case 0..<1.0:
            return CountdownPhase(number: 3, progress: elapsed, isVisible: true)
        case 1.0..<2.0:
            return CountdownPhase(number: 2, progress: elapsed - 1.0, isVisible: true)
        case 2.0..<3.0:
            return CountdownPhase(number: 1, progress: elapsed - 2.0, isVisible: true)
        case 3.0..<3.2:
            // Fade out phase
            let fadeProgress = (elapsed - 3.0) / 0.2
            return CountdownPhase(number: 0, progress: 1.0 - fadeProgress, isVisible: true)
        default:
            return CountdownPhase(number: 0, progress: 0, isVisible: false)
        }
    }
}

/// Represents a phase in the countdown animation
private struct CountdownPhase {
    let number: Int
    let progress: TimeInterval
    let isVisible: Bool

    /// Calculate scale based on progress (0.0 to 1.0)
    var scale: CGFloat {
        if progress < 0.4 {
            // Scale up from very small to large
            let t = progress / 0.4
            return 0.3 + (t * 0.7) // 0.3 → 1.0
        } else {
            // Hold at full size, never scale back down
            return 1.0
        }
    }

    /// Calculate opacity based on progress (0.0 to 1.0)
    var opacity: Double {
        if progress < 0.2 {
            // Fade in
            return progress / 0.2
        } else if progress < 0.9 {
            // Full opacity
            return 1.0
        } else {
            // Fade out
            let t = (progress - 0.9) / 0.1
            return 1.0 - (t * 0.7) // 1.0 → 0.3
        }
    }
}

/// View that renders a single countdown number with animations
private struct CountdownNumberView: View {
    let number: Int
    let progress: TimeInterval

    var body: some View {
        if number > 0 {
            let phase = CountdownPhase(number: number, progress: progress, isVisible: true)

            Text("\(number)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .scaleEffect(phase.scale)
                .opacity(phase.opacity)
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                .animation(.easeOut(duration: 0.4), value: phase.scale)
                .animation(.easeOut(duration: 0.2), value: phase.opacity)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CountdownOverlay_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background to simulate region selection
            Color.gray.opacity(0.3)

            CountdownOverlay {
                print("Countdown complete!")
            }
        }
        .frame(width: 1920, height: 1080)
    }
}
#endif
