import SwiftUI
import Carbon
import AppKit

/// A SwiftUI component for recording keyboard shortcuts
///
/// Displays the current shortcut and allows the user to record a new one
/// by clicking and pressing the desired key combination.
struct KeyboardShortcutRecorder: View {
    let action: KeyboardShortcut.Action
    @Binding var shortcut: KeyboardShortcut

    @State private var isRecording = false
    @State private var recordedShortcut: KeyboardShortcut?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: toggleRecording) {
                HStack {
                    if isRecording {
                        Text("Press keys...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(shortcut.displayString)
                            .font(.system(.body, design: .monospaced))
                    }

                    Spacer()

                    if !isRecording {
                        Image(systemName: "keyboard")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        Button(action: cancelRecording) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(width: 140)
                .background(isRecording ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isRecording ? Color.blue : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .background(KeyEventHandler(isRecording: $isRecording) { event in
                handleKeyEvent(event)
            })

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func toggleRecording() {
        if isRecording {
            cancelRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        recordedShortcut = nil
        errorMessage = nil
    }

    private func cancelRecording() {
        isRecording = false
        recordedShortcut = nil
        errorMessage = nil
    }

    private func stopRecording(with newShortcut: KeyboardShortcut) {
        shortcut = newShortcut
        recordedShortcut = nil
        errorMessage = nil
        isRecording = false
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        // Get the key code
        let keyCode = Int(event.keyCode)

        // Get modifiers
        var modifiers: KeyboardShortcut.ModifierFlags = []
        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }

        // Require at least one modifier key
        guard !modifiers.isEmpty else {
            errorMessage = "Must include at least one modifier (⌘, ⌥, ⇧, or ⌃)"
            return
        }

        // Create the shortcut
        let newShortcut = KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)

        // Validate
        guard newShortcut.isValid() else {
            errorMessage = "Invalid key combination"
            return
        }

        // Check for system reserved shortcuts
        if newShortcut.isSystemReserved() {
            errorMessage = "This shortcut is reserved by the system"
            return
        }

        // Success - save and stop recording
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            stopRecording(with: newShortcut)
        }
    }
}

/// A custom view that handles keyboard events for the shortcut recorder
private struct KeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.shouldAcceptKeyEvents = isRecording
    }

    class KeyEventView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?
        var shouldAcceptKeyEvents = false
        var localMonitor: Any?

        override var acceptsFirstResponder: Bool {
            return shouldAcceptKeyEvents
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            // Remove old monitor if exists
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
                localMonitor = nil
            }

            // Add new local monitor for key events
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, self.shouldAcceptKeyEvents else { return event }
                self.onKeyDown?(event)
                return nil // Consume the event
            }
        }

        deinit {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
