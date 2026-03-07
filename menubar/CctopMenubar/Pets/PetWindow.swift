import AppKit
import SwiftUI

/// Transparent, borderless, always-on-top window for a single desktop pet.
class PetWindow: NSPanel {
    let petId: String

    init(petId: String, petView: some View, petSize: CGFloat) {
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

        let hostingView = PetHostingView(rootView: petView)
        hostingView.petSize = petSize
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView

        // Set initial window frame to match pet size
        updateSize(petSize)
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
        if let hosting = contentView as? PetHostingViewProtocol {
            hosting.updatePetSize(petSize)
        }
    }
}

// MARK: - Hit-Test Restricted Hosting View

/// Protocol to update petSize without knowing the generic parameter.
@objc protocol PetHostingViewProtocol {
    func updatePetSize(_ size: CGFloat)
}

/// NSHostingView subclass that restricts hit testing to just the sprite
/// and name tag area. Clicks outside this region (Zzz particles, speech
/// bubbles, dust) pass through the window to apps behind it.
class PetHostingView<Content: View>: NSHostingView<Content>,
    PetHostingViewProtocol {
    var petSize: CGFloat = 64

    func updatePetSize(_ size: CGFloat) {
        petSize = size
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let centerX = bounds.midX
        let centerY = bounds.midY

        // The sprite frame is petSize × petSize, but the visible pixel
        // art only fills roughly the center 70%. Use that as hit area.
        let visibleW = petSize * 0.7
        let visibleH = petSize * 0.7
        // Name tag: offset petSize * 0.75 below center, ~12pt tall
        let nameBottom = centerY - petSize * 0.75 - 8

        let hitRect = NSRect(
            x: centerX - visibleW * 0.5,
            y: nameBottom,
            width: visibleW,
            height: (centerY + visibleH * 0.5) - nameBottom
        )

        if hitRect.contains(point) {
            return super.hitTest(point)
        }
        return nil
    }
}
