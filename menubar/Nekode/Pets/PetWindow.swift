import AppKit
import SwiftUI

/// Transparent, borderless, always-on-top window for a single desktop pet.
class PetWindow: NSPanel {
    let petId: String

    /// Z-order among pet windows. Higher = closer to viewer (in front).
    /// Updated each tick based on Y position (lower Y = higher index).
    var depthOrder: Int = 0 {
        didSet {
            guard depthOrder != oldValue else { return }
            // Use a sub-level offset so all pets stay in the .floating range
            // but are ordered relative to each other.
            level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + depthOrder)
        }
    }

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
        // Mouse events are accepted; hitTest in PetHostingView returns nil
        // for clicks outside the sprite, which lets them pass through.
        ignoresMouseEvents = false
        collectionBehavior = [
            .canJoinAllSpaces, .stationary, .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true

        let hostingView = PetHostingView(rootView: petView)
        hostingView.petSize = petSize
        hostingView.layer?.backgroundColor = .clear
        contentView = hostingView

        // Set initial window frame to match pet size
        updateSize(petSize)
    }

    // Never become key or main — prevents alt-tab focus stealing.
    // .nonactivatingPanel + ignoresMouseEvents handles event routing.
    override var canBecomeKey: Bool { false }
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

    private func spriteHitRect() -> NSRect {
        let centerX = bounds.midX
        let centerY = bounds.midY
        let visibleW = petSize * PetPhysics.hitboxFactor
        let visibleH = petSize * PetPhysics.hitboxFactor
        let downShift: CGFloat = petSize * PetPhysics.hitboxDownShift
        // Sprite body
        let spriteRect = NSRect(
            x: centerX - visibleW * 0.5,
            y: centerY - visibleH * 0.5 - downShift,
            width: visibleW,
            height: visibleH
        )
        // Name tag: sits below the sprite (offset petSize * 0.75 below center, ~14pt tall)
        let nameTagRect = NSRect(
            x: centerX - visibleW * 0.5,
            y: centerY - petSize * 0.75 - 8,
            width: visibleW,
            height: 16
        )
        return spriteRect.union(nameTagRect)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if spriteHitRect().contains(point) {
            return super.hitTest(point)
        }
        return nil
    }
}
