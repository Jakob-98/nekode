import SwiftUI

// MARK: - Main Pet View

struct PetView: View {
    @ObservedObject var pet: PetModel
    let petSize: CGFloat
    let onClick: () -> Void
    let onRightClick: (NSPoint) -> Void
    @State private var isHovering = false

    /// Sinusoidal breathing bob: 1-2px vertical oscillation, 2.5s cycle.
    /// Active during non-moving states to make the pet feel alive.
    private var breathingOffset: CGFloat {
        let cycle = sin(pet.breathAccumulator * 2.0 * .pi / 2.5)
        // Scale displacement by pet size: ~1-2px at 64pt
        return CGFloat(cycle) * (petSize / 64.0) * 1.5
    }

    var body: some View {
        ZStack {
            // Shadow ellipse below the sprite for visual grounding
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: petSize * 0.6, height: petSize * 0.15)
                .offset(y: petSize * 0.42)
                .blur(radius: 1.5)

            // Dust particles at pet's feet
            ForEach(pet.dustParticles) { particle in
                Circle()
                    .fill(Color.gray.opacity(particle.opacity * 0.6))
                    .frame(
                        width: particle.size,
                        height: particle.size
                    )
                    .offset(x: particle.x, y: petSize * 0.35 + particle.y)
            }
            .allowsHitTesting(false)

            // Zzz particles floating above sleeping pets
            ForEach(pet.zzzParticles) { particle in
                Text(particle.letter)
                    .font(.system(
                        size: particle.size,
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundStyle(.white.opacity(particle.opacity * 0.7))
                    .offset(
                        x: particle.x,
                        y: petSize * 0.0 + particle.y
                    )
            }
            .allowsHitTesting(false)

            // Sprite anchored at center — breathing bob applied as offset
            SpriteSheetView(
                kind: pet.kind,
                state: pet.visualState,
                frame: pet.currentFrame,
                petSize: petSize
            )
            .scaleEffect(pet.visualState.spriteScale)
            .scaleEffect(x: pet.facingRight ? 1 : -1, y: 1)
            .scaleEffect(x: pet.scaleX, y: pet.scaleY)
            .scaleEffect(pet.scale)
            .offset(y: breathingOffset)
            .opacity(pet.opacity)
            .onHover { isHovering = $0 }

            // Speech bubble floats above sprite with slide+fade animation
            PetSpeechBubble(text: pet.speechBubble ?? "")
                .offset(y: -petSize * 0.7 + (pet.speechBubble != nil ? 0 : 8))
                .opacity(pet.speechBubble != nil ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: pet.speechBubble != nil)
                .allowsHitTesting(false)

            // Name tag sits below sprite (always in layout, opacity-toggled)
            PetNameTag(text: pet.displayName)
                .offset(y: petSize * 0.75)
                .opacity(isHovering || pet.needsAttention ? 1 : 0)
        }
        .frame(width: petSize * 2, height: petSize * 2.5)
        .overlay(
            PetInteractionOverlay(
                pet: pet,
                petSize: petSize,
                onClick: onClick,
                onRightClick: onRightClick
            )
        )
    }
}

// MARK: - AppKit Mouse Event Handler

/// Handles drag, click, and right-click at the AppKit level.
/// SwiftUI gestures don't reliably receive events through non-activating panels.
struct PetInteractionOverlay: NSViewRepresentable {
    let pet: PetModel
    let petSize: CGFloat
    let onClick: () -> Void
    let onRightClick: (NSPoint) -> Void

    func makeNSView(context: Context) -> PetMouseView {
        PetMouseView(
            pet: pet,
            petSize: petSize,
            onClick: onClick,
            onRightClick: onRightClick
        )
    }

    func updateNSView(_ nsView: PetMouseView, context: Context) {
        nsView.pet = pet
        nsView.petSize = petSize
        nsView.onClick = onClick
        nsView.onRightClick = onRightClick
    }
}

/// NSView subclass that receives all mouse events directly from the window.
/// Works reliably in non-activating NSPanel (unlike SwiftUI gestures).
///
/// Click vs drag discrimination: if the cursor moves less than `tapThreshold`
/// between mouseDown and mouseUp, it's treated as a tap (fires onClick).
/// Otherwise it's a drag (repositions the pet).
class PetMouseView: NSView {
    var pet: PetModel
    var petSize: CGFloat
    var onClick: () -> Void
    var onRightClick: (NSPoint) -> Void
    private var dragStartModelPosition: CGPoint?
    private var dragStartScreenPoint: NSPoint?
    /// Whether the mouse moved far enough to count as a real drag.
    private var didDrag: Bool = false

    /// Max cursor travel (points) for a mouseDown→mouseUp to count as a tap.
    private static let tapThreshold: CGFloat = 4

    init(
        pet: PetModel,
        petSize: CGFloat,
        onClick: @escaping () -> Void,
        onRightClick: @escaping (NSPoint) -> Void
    ) {
        self.pet = pet
        self.petSize = petSize
        self.onClick = onClick
        self.onRightClick = onRightClick
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Only accept hits within the sprite area so clicks in the empty
    /// parts of the oversized window pass through to apps behind it.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        let centerX = bounds.midX
        let centerY = bounds.midY
        let hitW = petSize * PetPhysics.hitboxFactor
        let hitH = petSize * PetPhysics.hitboxFactor
        let downShift = petSize * PetPhysics.hitboxDownShift
        let spriteRect = NSRect(
            x: centerX - hitW * 0.5,
            y: centerY - hitH * 0.5 - downShift,
            width: hitW,
            height: hitH
        )
        if spriteRect.contains(local) {
            return super.hitTest(point)
        }
        return nil
    }

    override func mouseDown(with event: NSEvent) {
        // Ignore extra clicks in a multi-click sequence — the first click's
        // mouseUp already handled the tap. Without this, the second click
        // would pass through to the newly-focused app behind.
        guard event.clickCount <= 1 else { return }
        didDrag = false
        dragStartModelPosition = pet.position
        dragStartScreenPoint = NSEvent.mouseLocation
        (window as? PetWindow)?.isDragging = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.pet.state == .sleeping {
                self.pet.sleepWakeTimeRemaining = PetPhysics.sleepWakeDuration
                self.pet.currentFrame = 0
                self.pet.frameAccumulator = 0
            }
            self.pet.isDragging = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startModel = dragStartModelPosition,
              let startScreen = dragStartScreenPoint else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - startScreen.x
        let dy = current.y - startScreen.y

        // Once movement exceeds the tap threshold, commit to dragging
        if !didDrag {
            let distance = sqrt(dx * dx + dy * dy)
            if distance >= Self.tapThreshold {
                didDrag = true
            }
        }

        if didDrag {
            DispatchQueue.main.async { [weak self] in
                self?.pet.position = CGPoint(
                    x: startModel.x + dx,
                    y: startModel.y + dy
                )
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStartModelPosition != nil else { return }
        let wasDrag = didDrag
        dragStartModelPosition = nil
        dragStartScreenPoint = nil
        didDrag = false

        let petWindow = window as? PetWindow
        petWindow?.isDragging = false
        petWindow?.ignoresMouseEvents = true

        if wasDrag {
            // Real drag — drop the pet
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pet.isDragging = false
                PetAnimationEngine.triggerSquash(
                    self.pet, scaleX: 1.15, scaleY: 0.85, duration: 0.1
                )
                PetAnimationEngine.spawnDust(self.pet)
                if self.pet.state.isAttentionSeeking {
                    self.pet.dismissedStatus = self.pet.session.status
                    if let savedHome = self.pet.preChaseHome {
                        self.pet.lastDropPosition = savedHome
                        self.pet.preChaseHome = nil
                    }
                    self.pet.attentionTime = 0
                    let restState: PetState = self.pet.session.status == .idle ? .sleeping : .sitting
                    self.pet.state = restState
                    self.pet.velocity = .zero
                    self.pet.currentFrame = 0
                    self.pet.frameAccumulator = 0
                } else {
                    self.pet.lastDropPosition = self.pet.position
                    self.pet.hasCustomHome = true
                }
            }
        } else {
            // Tap — acknowledge attention (dismiss alert) and jump to session
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pet.isDragging = false
                if self.pet.state.isAttentionSeeking {
                    self.pet.dismissedStatus = self.pet.session.status
                    if let savedHome = self.pet.preChaseHome {
                        self.pet.lastDropPosition = savedHome
                        self.pet.preChaseHome = nil
                    }
                    self.pet.attentionTime = 0
                    let restState: PetState = self.pet.session.status == .idle ? .sleeping : .sitting
                    self.pet.state = restState
                    self.pet.velocity = .zero
                    self.pet.currentFrame = 0
                    self.pet.frameAccumulator = 0
                }
                self.onClick()
            }
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        let screenPoint = NSEvent.mouseLocation
        DispatchQueue.main.async { [weak self] in
            self?.onRightClick(screenPoint)
        }
    }
}

// MARK: - Placeholder Sprite (SF Symbol)

struct PlaceholderSprite: View {
    let kind: PetKind
    let state: PetState
    let frame: Int
    let petSize: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: petSize * 0.15)
                .fill(Color(hue: kind.placeholderHue, saturation: 0.3, brightness: 0.35))
                .frame(width: petSize, height: petSize)
            Image(systemName: kind.placeholderSymbol(for: state))
                .font(.system(size: petSize * 0.45))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

// MARK: - Speech Bubble

struct PetSpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.75))
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
            )
    }
}

// MARK: - Name Tag

struct PetNameTag: View {
    let text: String

    var body: some View {
        Text(String(text.prefix(30)))
            .font(.system(size: 7, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(.black.opacity(0.6))
            )
    }
}

// MARK: - Preview

#Preview("Pochi Sitting") {
    PetPreviewFactory.makePreview(status: .working, kind: .pochi)
}

#Preview("Black Cat Alerting") {
    PetPreviewFactory.makePreview(status: .waitingInput, kind: .pochiBlack)
}

#Preview("Orange Cat Sleeping") {
    PetPreviewFactory.makePreview(status: .idle, kind: .pochiOrange)
}

/// Factory to work around `#Preview` result builder limitations with imperative setup.
@MainActor
enum PetPreviewFactory {
    static func makePreview(
        status: SessionStatus, kind: PetKind
    ) -> some View {
        let pet = PetModel(
            session: .mock(status: status),
            kind: kind,
            screenBounds: NSRect(x: 0, y: 0, width: 1440, height: 900)
        )
        pet.opacity = 1
        pet.scale = 1
        return PetView(
            pet: pet, petSize: 64,
            onClick: {}, onRightClick: { _ in }
        )
        .frame(width: 200, height: 200)
        .background(.black.opacity(0.3))
    }
}
