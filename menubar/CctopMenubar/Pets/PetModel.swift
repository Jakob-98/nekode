import AppKit
import Foundation

/// Per-pet state: position, velocity, animation, and session binding.
@MainActor
class PetModel: ObservableObject, Identifiable {
    let id: String               // Matches session PID-based ID
    var kind: PetKind
    var session: Session

    // MARK: - Spatial

    @Published var position: CGPoint     // Screen coordinates (bottom-left origin)
    @Published var velocity: CGPoint = .zero // 2D speed (negative x = left, negative y = down)
    @Published var facingRight: Bool = true

    // MARK: - Animation

    @Published var state: PetState
    @Published var currentFrame: Int = 0
    var frameAccumulator: Double = 0     // Fractional frame counter for FPS

    // MARK: - Behavior

    @Published var isDragging: Bool = false
    var target: CGPoint?                 // Where to move toward (nil = roaming)
    var roamPauseUntil: Date?            // Random pause during roaming
    var lastDropPosition: CGPoint?       // Where user last dropped the pet (its "home")
    /// When user drags an attention-seeking pet, the status is stored here.
    /// Prevents the engine from immediately re-setting the pet to alerting/barking
    /// until the session status actually changes to something different.
    var dismissedStatus: SessionStatus?

    // MARK: - Speech Bubbles

    @Published var activeBubbleText: String?
    var bubbleTimeRemaining: Double = 0  // How long current bubble stays
    var bubbleCooldown: Double = 15      // Seconds until next bubble check

    // MARK: - Lifecycle

    @Published var opacity: Double = 1.0
    @Published var scale: Double = 1.0
    var isAppearing: Bool = false
    var isDisappearing: Bool = false
    var shouldRemove: Bool = false

    // MARK: - Computed

    var displayName: String { session.displayName }
    var needsAttention: Bool { session.status.needsAttention }

    /// The visual state for sprite rendering — uses walking animation while
    /// the pet is moving to its home spot, even if logical state is sitting.
    var visualState: PetState {
        if state == .sitting && velocity != .zero {
            return .walking
        }
        return state
    }

    /// Speech bubble text — priority: active engine bubble > attention symbol
    var speechBubble: String? {
        if let active = activeBubbleText {
            return active
        }
        switch state {
        case .barking: return "!"
        case .alerting: return "?"
        default: return nil
        }
    }

    // MARK: - Init

    init(session: Session, kind: PetKind, screenBounds: CGRect) {
        self.id = session.id
        self.kind = kind
        self.session = session
        self.state = PetState(from: session.status)

        // Spawn near top of screen (menubar area), spread horizontally
        let xRange = screenBounds.minX + 40...screenBounds.maxX - 40
        let spawnX = CGFloat.random(in: xRange)
        let spawnY = screenBounds.maxY - 40
        self.position = CGPoint(x: spawnX, y: spawnY)
        self.lastDropPosition = self.position

        // Start with appear animation
        self.opacity = 0
        self.scale = 0.5
        self.isAppearing = true
    }
}
