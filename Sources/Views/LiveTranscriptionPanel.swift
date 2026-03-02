import AppKit
import SwiftUI

// MARK: - Panel Controller

@MainActor
class LiveTranscriptionPanelController {
    private var panel: NSPanel?

    func show() {
        if panel != nil { return }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true

        let hostingView = NSHostingView(rootView: LiveTranscriptionOverlayView())
        panel.contentView = hostingView

        // Position bottom-center, above the dock
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 200
            let y = screenFrame.minY + 80
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - SwiftUI Overlay View

struct LiveTranscriptionOverlayView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        HStack(spacing: 10) {
            // Pulsing recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .modifier(PulseModifier())

            // Transcription text
            if let text = appState.liveTranscriptionText, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Listening...")
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 200, maxWidth: 400)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pulse Animation

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}
