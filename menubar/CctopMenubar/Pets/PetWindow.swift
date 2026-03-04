import AppKit
import SwiftUI

/// Transparent, borderless, always-on-top window for a single desktop pet.
class PetWindow: NSPanel {
    let petId: String

    init(petId: String, petView: some View) {
        self.petId = petId
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 160),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary
        ]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        // Accept mouse-moved events so gestures work without key status
        acceptsMouseMovedEvents = true

        let hostingView = NSHostingView(rootView: petView)
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView
    }

    // Allow becoming key briefly for gesture delivery, but
    // .nonactivatingPanel prevents stealing focus from the user's app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Update window position from model coordinates.
    /// Model uses bottom-left screen origin; NSWindow.setFrameOrigin also
    /// uses bottom-left, so we center the pet in the window on both axes.
    func syncPosition(position: CGPoint, petSize: CGFloat) {
        let originX = position.x - frame.width / 2
        let originY = position.y - frame.height / 2
        setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    /// Resize when pet size preference changes.
    func updateSize(_ petSize: CGFloat) {
        let width = petSize * 2    // Extra width for name tag overflow
        let height = petSize * 2.5 // Extra height for speech bubble + name tag
        let newFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: width,
            height: height
        )
        setFrame(newFrame, display: true)
    }
}
