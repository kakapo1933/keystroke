import Cocoa
import SwiftUI

class OverlayPanel: NSPanel {
    private let viewModel: KeystrokeViewModel
    private var isDraggable = false

    init(viewModel: KeystrokeViewModel) {
        self.viewModel = viewModel

        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 260

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false

        let hostingView = NSHostingView(
            rootView: KeystrokeOverlayView(viewModel: viewModel)
        )
        contentView = hostingView

        positionAtBottom()
        orderFrontRegardless()
    }

    // MARK: - Lock / Unlock for dragging

    func setLocked(_ locked: Bool) {
        isDraggable = !locked
        ignoresMouseEvents = locked
        viewModel.isEditing = !locked
    }

    override var canBecomeKey: Bool {
        isDraggable
    }

    override func sendEvent(_ event: NSEvent) {
        if isDraggable && event.type == .leftMouseDown {
            performDrag(with: event)
            return
        }
        super.sendEvent(event)
    }

    // MARK: - Positioning

    func positionAtBottom() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.minY + 80
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
