import AppKit
import Foundation
import QuartzCore

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
    var breathAccumulator: Double = 0    // Sinusoidal breathing cycle (seconds)

    // MARK: - Squash/Stretch

    @Published var scaleX: CGFloat = 1.0
    @Published var scaleY: CGFloat = 1.0
    var squashTimeRemaining: Double = 0  // Seconds left in squash animation
    var squashDuration: Double = 0.12    // Original duration (for easing calculation)
    var squashTargetX: CGFloat = 1.0     // Target scaleX to ease toward
    var squashTargetY: CGFloat = 1.0     // Target scaleY to ease toward

    // MARK: - Behavior

    @Published var isDragging: Bool = false
    var target: CGPoint?                 // Where to move toward (nil = roaming)
    var roamPauseUntil: Double = 0       // Monotonic time (CACurrentMediaTime) to resume
    var lastDropPosition: CGPoint?       // Where user last dropped the pet (its "home")
    /// When true, the pet uses its `lastDropPosition` as a personal home
    /// instead of the shared vibe zone. Set when user drags the pet somewhere.
    /// Cleared when the pet is reset to the vibe zone via context menu.
    var hasCustomHome: Bool = false
    /// Saved home position before the pet starts chasing the mouse.
    /// Restored as `lastDropPosition` when the user drag-dismisses.
    var preChaseHome: CGPoint?
    /// When user drags an attention-seeking pet, the status is stored here.
    /// Prevents the engine from immediately re-setting the pet to alerting/barking
    /// until the session status actually changes to something different.
    var dismissedStatus: SessionStatus?

    // MARK: - Spawn Run-In

    /// When true, the pet is running in from the right edge of the screen
    /// toward its target position in the vibe zone. Overrides normal state behavior.
    var isRunningIn: Bool = false
    /// The target point the pet is running toward during the spawn run-in.
    var runInTarget: CGPoint?

    // MARK: - Sleep Drift

    /// Target point for sleeping wander — separate from lastDropPosition
    /// so we don't lose the pet's "home" while it drifts.
    var sleepDriftTarget: CGPoint?
    /// Whether the sleeping pet is currently drifting (vs pausing).
    var sleepDrifting: Bool = false

    // MARK: - Attention Escalation

    /// How long (seconds) the pet has been in an attention-seeking state.
    /// Drives the 4-stage escalation: perk up → approach → insistent → urgent.
    var attentionTime: Double = 0

    /// Current attention escalation stage (1-4), computed from `attentionTime`.
    var attentionStage: Int {
        if attentionTime < 10 { return 1 }    // Perk up (stay put, face cursor)
        if attentionTime < 30 { return 2 }    // Approach (walk toward, 50px stop)
        if attentionTime < 60 { return 3 }    // Insistent (faster, 30px stop)
        return 4                               // Urgent (run, 20px stop, bounce)
    }

    /// Monotonic time for the next bounce squash in stage 4.
    var attentionBounceNext: Double = 0

    // MARK: - Roaming (Smooth Wander)

    /// Current movement heading in radians (0 = right, π/2 = up).
    var roamHeading: CGFloat = CGFloat.random(in: 0...(2 * .pi))
    /// Desired heading to steer toward (resampled periodically).
    var roamDesiredHeading: CGFloat = CGFloat.random(in: 0...(2 * .pi))
    /// Monotonic time when the next random direction change occurs.
    var roamNextDirectionChange: Double = 0

    // MARK: - Zzz Particles

    struct ZzzParticle: Identifiable {
        let id = UUID()
        var x: CGFloat        // Offset from pet center
        var y: CGFloat        // Offset from pet center
        var opacity: Double
        var size: CGFloat
        let lifetime: Double  // Total lifetime
        var age: Double = 0   // Current age
        let letter: String    // "z", "Z", or "z"
    }

    @Published var zzzParticles: [ZzzParticle] = []
    /// Monotonic time when the next Zzz particle spawns.
    var zzzNextSpawn: Double = 0

    // MARK: - Idle Tiers

    /// How long (seconds) the pet has been sitting with zero velocity.
    /// Resets on state change, interaction, or velocity.
    var idleTime: Double = 0

    /// Current idle tier (0 = just sat down, 1-3 = escalating boredom).
    var idleTier: Int {
        if idleTime < 5 { return 0 }      // Just sat down (0-5s)
        if idleTime < 30 { return 1 }     // Attentive (5-30s)
        if idleTime < 120 { return 2 }    // Bored (30-120s)
        return 3                            // Drowsy (120s+)
    }

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

    // MARK: - Dust Particles

    struct DustParticle: Identifiable {
        let id = UUID()
        var x: CGFloat        // Offset from pet center
        var y: CGFloat        // Offset from pet center
        var opacity: Double
        var size: CGFloat
        let lifetime: Double  // Total lifetime
        var age: Double = 0   // Current age
    }

    @Published var dustParticles: [DustParticle] = []

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

    init(session: Session, kind: PetKind, screenBounds: CGRect, vibeZone: CGRect? = nil) {
        self.id = session.id
        self.kind = kind
        self.session = session
        self.state = PetState(from: session.status)

        if let zone = vibeZone {
            // Spawn off the right edge of the screen, vertically aligned with the vibe zone
            let spawnX = screenBounds.maxX + 40
            let spawnY = zone.midY + CGFloat.random(in: -zone.height / 4...zone.height / 4)
            self.position = CGPoint(x: spawnX, y: spawnY)

            // Pick a random target inside the vibe zone to run toward
            let targetX = CGFloat.random(in: zone.minX + 20...zone.maxX - 20)
            let targetY = CGFloat.random(in: zone.minY + 20...zone.maxY - 20)
            self.runInTarget = CGPoint(x: targetX, y: targetY)
            self.lastDropPosition = self.runInTarget
            self.isRunningIn = true
            self.facingRight = false  // Running leftward from right edge

            // Fully visible immediately — no fade, just running in
            self.opacity = 1
            self.scale = 1
            self.isAppearing = false
        } else {
            // Fallback: spawn near top of screen (legacy behavior)
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
}
