import SwiftUI

// MARK: - Main Pet View

struct PetView: View {
    @ObservedObject var pet: PetModel
    let petSize: CGFloat
    let onDoubleClick: () -> Void
    let onRightClick: (NSPoint) -> Void
    @State private var isHovering = false
    @State private var bubbleOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            // Speech bubble
            if let bubble = pet.speechBubble {
                PetSpeechBubble(text: bubble)
                    .offset(y: bubbleOffset)
                    .onAppear { bubbleOffset = -4 }
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                        value: bubbleOffset
                    )
                    .transition(.opacity.combined(with: .scale))
            }

            // Sprite (real sprite sheet with SF Symbol fallback)
            SpriteSheetView(
                kind: pet.kind,
                state: pet.visualState,
                frame: pet.currentFrame,
                petSize: petSize
            )
            .scaleEffect(x: pet.facingRight ? 1 : -1, y: 1)
            .scaleEffect(pet.scale)
            .opacity(pet.opacity)

            // Name tag
            if isHovering || pet.needsAttention {
                PetNameTag(text: pet.displayName)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .frame(width: petSize * 2, height: petSize * 2.5)
        .overlay(
            PetInteractionOverlay(
                pet: pet,
                onDoubleClick: onDoubleClick,
                onRightClick: onRightClick
            )
        )
        .onHover { isHovering = $0 }
    }
}

// MARK: - AppKit Mouse Event Handler

/// Handles drag, double-click, and right-click at the AppKit level.
/// SwiftUI gestures don't reliably receive events through non-activating panels.
struct PetInteractionOverlay: NSViewRepresentable {
    let pet: PetModel
    let onDoubleClick: () -> Void
    let onRightClick: (NSPoint) -> Void

    func makeNSView(context: Context) -> PetMouseView {
        PetMouseView(
            pet: pet,
            onDoubleClick: onDoubleClick,
            onRightClick: onRightClick
        )
    }

    func updateNSView(_ nsView: PetMouseView, context: Context) {
        nsView.pet = pet
        nsView.onDoubleClick = onDoubleClick
        nsView.onRightClick = onRightClick
    }
}

/// NSView subclass that receives all mouse events directly from the window.
/// Works reliably in non-activating NSPanel (unlike SwiftUI gestures).
class PetMouseView: NSView {
    var pet: PetModel
    var onDoubleClick: () -> Void
    var onRightClick: (NSPoint) -> Void
    private var dragStartModelPosition: CGPoint?
    private var dragStartScreenPoint: NSPoint?

    init(
        pet: PetModel,
        onDoubleClick: @escaping () -> Void,
        onRightClick: @escaping (NSPoint) -> Void
    ) {
        self.pet = pet
        self.onDoubleClick = onDoubleClick
        self.onRightClick = onRightClick
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            DispatchQueue.main.async { [weak self] in
                self?.onDoubleClick()
            }
            return
        }
        // Start drag
        dragStartModelPosition = pet.position
        dragStartScreenPoint = NSEvent.mouseLocation
        DispatchQueue.main.async { [weak self] in
            self?.pet.isDragging = true
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startModel = dragStartModelPosition,
              let startScreen = dragStartScreenPoint else { return }
        let current = NSEvent.mouseLocation
        // Screen coordinates: Y-up, same as model coordinates
        let dx = current.x - startScreen.x
        let dy = current.y - startScreen.y
        DispatchQueue.main.async { [weak self] in
            self?.pet.position = CGPoint(
                x: startModel.x + dx,
                y: startModel.y + dy
            )
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard dragStartModelPosition != nil else { return }
        dragStartModelPosition = nil
        dragStartScreenPoint = nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pet.isDragging = false
            self.pet.lastDropPosition = self.pet.position
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
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(.black.opacity(0.6))
            )
    }
}

// MARK: - Preview

#Preview("Dog Walking") {
    PetPreviewFactory.makePreview(status: .working, kind: .dog)
}

#Preview("Cat Alerting") {
    PetPreviewFactory.makePreview(status: .waitingInput, kind: .cat)
}

#Preview("Hamster Sleeping") {
    PetPreviewFactory.makePreview(status: .idle, kind: .hamster)
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
            onDoubleClick: {}, onRightClick: { _ in }
        )
        .frame(width: 200, height: 200)
        .background(.black.opacity(0.3))
    }
}
