import Cocoa
import Combine
import SwiftUI

class OverlayPanel: NSPanel {
    private let viewModel: KeystrokeViewModel
    private let preferences: KeystrokePreferences
    private var isDraggable = false
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: KeystrokeViewModel, preferences: KeystrokePreferences) {
        self.viewModel = viewModel
        self.preferences = preferences

        let panelSize = KeystrokeOverlayView.panelSize(for: preferences)

        super.init(
            contentRect: NSRect(origin: .zero, size: panelSize),
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
            rootView: KeystrokeOverlayView(viewModel: viewModel, preferences: preferences)
        )
        contentView = hostingView

        restoreSavedPositionOrDefault()
        observePreferenceChanges()
        observeWindowMoves()
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
            preferences.saveOverlayOrigin(frame.origin)
            return
        }
        super.sendEvent(event)
    }

    // MARK: - Positioning

    func positionAtBottom(savePosition: Bool = true) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let origin = NSPoint(
            x: screenFrame.midX - frame.width / 2,
            y: screenFrame.minY + 80
        )
        setFrameOrigin(constrainedOrigin(origin, size: frame.size))

        if savePosition {
            preferences.saveOverlayOrigin(frame.origin)
        }
    }

    func resetPosition() {
        preferences.clearOverlayOrigin()
        positionAtBottom()
    }

    private func restoreSavedPositionOrDefault() {
        guard let savedOrigin = preferences.savedOverlayOrigin else {
            positionAtBottom(savePosition: false)
            return
        }

        setFrameOrigin(constrainedOrigin(savedOrigin, size: frame.size))
    }

    private func observePreferenceChanges() {
        preferences.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.resizeForCurrentPreferences()
                }
            }
            .store(in: &cancellables)
    }

    private func observeWindowMoves() {
        NotificationCenter.default.publisher(for: NSWindow.didMoveNotification, object: self)
            .sink { [weak self] _ in
                guard let self, self.isDraggable else { return }
                self.preferences.saveOverlayOrigin(self.frame.origin)
            }
            .store(in: &cancellables)
    }

    private func resizeForCurrentPreferences() {
        let oldFrame = frame
        let newSize = KeystrokeOverlayView.panelSize(for: preferences)
        guard oldFrame.size != newSize else { return }

        let origin = NSPoint(
            x: oldFrame.midX - newSize.width / 2,
            y: oldFrame.minY
        )
        let newOrigin = constrainedOrigin(origin, size: newSize)
        setFrame(NSRect(origin: newOrigin, size: newSize), display: true)
        preferences.saveOverlayOrigin(frame.origin)
    }

    private func constrainedOrigin(_ origin: CGPoint, size: CGSize) -> CGPoint {
        let proposedFrame = NSRect(origin: origin, size: size)
        let screen = bestScreen(for: proposedFrame) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return origin }

        let maxX = max(visibleFrame.minX, visibleFrame.maxX - size.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - size.height)

        return CGPoint(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY)
        )
    }

    private func bestScreen(for rect: NSRect) -> NSScreen? {
        NSScreen.screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(rect).area < rhs.visibleFrame.intersection(rect).area
        }
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
