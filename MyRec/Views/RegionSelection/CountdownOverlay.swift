import SwiftUI

/// Simple countdown overlay showing 3-2-1 before recording starts
struct CountdownOverlay: View {
    let onComplete: () -> Void

    @State private var currentCount = 3
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0

    var body: some View {
        // Number display with animations
        Text("\(currentCount)")
            .font(.system(size: 140, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .scaleEffect(scale)
            .opacity(opacity)
            .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            .onAppear {
                startCountdown()
            }
    }

    private func startCountdown() {
        // Show 3 with animation
        currentCount = 3
        animateNumber()

        // Change to 2 after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            currentCount = 2
            animateNumber()
        }

        // Change to 1 after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            currentCount = 1
            animateNumber()
        }

        // Complete countdown after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.2)) {
                opacity = 0
                scale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onComplete()
            }
        }
    }

    private func animateNumber() {
        // Reset for new number
        scale = 0.5
        opacity = 0

        // Animate in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            scale = 1.2
            opacity = 1.0
        }

        // Slight bounce back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
            }
        }

        // Fade out before next number
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                opacity = 0.3
                scale = 0.9
            }
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
