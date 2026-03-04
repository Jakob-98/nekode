import SwiftUI

// MARK: - Main Pet View

struct PetView: View {
    @ObservedObject var pet: PetModel
    let petSize: CGFloat
    let onDoubleClick: () -> Void
    let onRightClick: (NSPoint) -> Void
    @State private var isHovering = false
    @State private var bubbleOffset: CGFloat = 0
    @State private var dragStartPosition: CGPoint?

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
                state: pet.state,
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
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .gesture(dragGesture)
        .onTapGesture(count: 2) { onDoubleClick() }
        .onRightClick { point in onRightClick(point) }
    }

    private var dragGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                if dragStartPosition == nil {
                    dragStartPosition = pet.position
                    pet.isDragging = true
                }
                guard let start = dragStartPosition else { return }
                // value.translation is the delta from drag start in
                // the window's coordinate space. Y is flipped (SwiftUI
                // Y-down vs screen Y-up), so negate the Y component.
                pet.position = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y - value.translation.height
                )
            }
            .onEnded { _ in
                dragStartPosition = nil
                pet.isDragging = false
                // Pet stays where dropped — no freeze timer
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
            // Background shape
            RoundedRectangle(cornerRadius: petSize * 0.15)
                .fill(backgroundColor)
                .frame(width: petSize, height: petSize)

            // SF Symbol
            symbolView
        }
    }

    @ViewBuilder
    private var symbolView: some View {
        let base = Image(systemName: kind.placeholderSymbol(for: state))
            .font(.system(size: petSize * 0.45))
            .foregroundStyle(symbolColor)
        if #available(macOS 14.0, *) {
            base.symbolEffect(.pulse, options: .repeating,
                              isActive: state.isAttentionSeeking)
        } else {
            base.opacity(state.isAttentionSeeking ? 0.6 : 1.0)
        }
    }

    private var backgroundColor: Color {
        let hue = kind.placeholderHue
        switch state {
        case .sleeping:
            return Color(hue: hue, saturation: 0.2, brightness: 0.3)
        case .alerting, .barking:
            return Color(hue: 0.08, saturation: 0.6, brightness: 0.5)
        case .spinning:
            return Color(hue: 0.15, saturation: 0.4, brightness: 0.4)
        default:
            return Color(hue: hue, saturation: 0.3, brightness: 0.35)
        }
    }

    private var symbolColor: Color {
        switch state {
        case .sleeping:
            return .white.opacity(0.5)
        case .alerting, .barking:
            return .white
        default:
            return .white.opacity(0.85)
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

// MARK: - Right-Click Modifier

/// Detects right-click (context menu trigger) on a view.
struct RightClickModifier: ViewModifier {
    let action: (NSPoint) -> Void

    func body(content: Content) -> some View {
        content.overlay(
            RightClickOverlay(action: action)
        )
    }
}

struct RightClickOverlay: NSViewRepresentable {
    let action: (NSPoint) -> Void

    func makeNSView(context: Context) -> RightClickDetector {
        RightClickDetector(action: action)
    }

    func updateNSView(_ nsView: RightClickDetector, context: Context) {
        nsView.action = action
    }
}

class RightClickDetector: NSView {
    var action: (NSPoint) -> Void

    init(action: @escaping (NSPoint) -> Void) {
        self.action = action
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func rightMouseDown(with event: NSEvent) {
        let screenPoint = NSEvent.mouseLocation
        action(screenPoint)
    }
}

extension View {
    func onRightClick(perform action: @escaping (NSPoint) -> Void) -> some View {
        modifier(RightClickModifier(action: action))
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
