import Foundation

enum PetState: Int, CaseIterable {
    case sleeping       // session idle (no activity)
    case sitting        // session working (agent is busy, pet chills)
    case walking        // roaming (transitional or gentle movement)
    case running        // attention seeking (chasing mouse cursor)
    case alerting       // waitingInput, needsAttention
    case barking        // waitingPermission
    case spinning       // compacting
    case appearing      // spawn animation
    case disappearing   // despawn animation

    /// Which row in the sprite sheet this state corresponds to.
    var spriteRow: Int {
        switch self {
        case .sleeping: return 3
        case .sitting: return 0
        case .walking: return 1
        case .running: return 2
        case .alerting: return 4
        case .barking: return 4
        case .spinning: return 5
        case .appearing: return 0
        case .disappearing: return 0
        }
    }

    /// Number of animation frames for this state.
    /// Dog/cat have 6-frame walk/run; hamster has 4.
    /// Use `frameCount(for:)` for per-kind counts.
    var frameCount: Int {
        switch self {
        case .sleeping: return 2
        case .sitting: return 4
        case .walking: return 6   // Clamped per-kind in engine
        case .running: return 6   // Clamped per-kind in engine
        case .alerting: return 4
        case .barking: return 4
        case .spinning: return 4
        case .appearing: return 1
        case .disappearing: return 1
        }
    }

    /// Per-kind frame count (handles dog/cat vs hamster differences).
    func frameCount(for kind: PetKind) -> Int {
        switch (self, kind) {
        case (.walking, .hamster), (.running, .hamster):
            return 4
        default:
            return frameCount
        }
    }

    /// Whether this animation loops continuously.
    var loops: Bool {
        switch self {
        case .appearing, .disappearing: return false
        default: return true
        }
    }

    /// Map a SessionStatus to the corresponding pet animation state.
    /// Working = sitting (pet chills while agent is busy)
    /// Attention states = running (pet chases mouse cursor)
    init(from status: SessionStatus) {
        switch status {
        case .idle: self = .sleeping
        case .working: self = .sitting
        case .compacting: self = .spinning
        case .waitingInput, .needsAttention: self = .alerting
        case .waitingPermission: self = .barking
        }
    }

    /// Whether the pet should be actively moving in this state.
    /// Note: .walking and .running are visual-only states (used by visualState
    /// for sprite selection) and are never set as actual pet states.
    var isMoving: Bool {
        switch self {
        case .alerting, .barking: return true
        default: return false
        }
    }

    /// Whether this state represents an attention-seeking behavior.
    var isAttentionSeeking: Bool {
        switch self {
        case .alerting, .barking: return true
        default: return false
        }
    }
}
