import Foundation

/// Pet animation states — maps to rows in the Pochi sprite sheet.
///
/// Row/frame metadata lives in `SpriteGridConfig.swift` (PochiSpriteGrid).
/// This enum defines behavioral states; sprite details are looked up from
/// the grid config via `gridKey`.
enum PetState: Int, CaseIterable {
    // Core states (set by session status mapping)
    case sitting        // session working (agent busy, pet chills)          → row 0
    case sleeping       // session idle (no activity)                        → row 3
    case alerting       // waitingInput, needsAttention — hurt walk         → row 17
    case barking        // waitingPermission — dash/burst                   → row 18
    case spinning       // compacting                                        → row 8

    // Movement states (set by visualState or animation engine)
    case walking        // gentle movement to home/vibe zone                → row 5
    case running        // fast chase (attention stage 4)                   → row 6
    case sneaking       // low crawl — bored idle variant                   → row 4
    case dashing        // burst run-in from screen edge                    → row 18

    // Idle variant states (cycled through during working/idle)
    case standing       // standing idle / attentive                         → row 1
    case boxIdle        // sitting in box (idle)                             → row 7
    case boxWiggle      // box wiggle / playful shake                       → row 8

    // Expression states (set by animation engine for transitions)
    case dancing        // happy dance — satisfied after attention resolved  → row 11
    case grooming       // face cleaning — idle variant                     → row 13
    case lookingUp      // sitting looking up — idle variant                → row 12

    // Lifecycle
    case appearing      // spawn animation                                   → row 0
    case disappearing   // despawn animation                                 → row 0

    // MARK: - Grid Config Key

    /// Maps this state to its key in `PochiSpriteGrid`.
    /// Multiple states can share a grid key (e.g. spinning/boxWiggle → "boxWiggle",
    /// barking/dashing → "dashing"). Lifecycle states fall back to "sitting".
    var gridKey: String {
        switch self {
        case .sitting:      return "sitting"
        case .sleeping:     return "sleeping"
        case .alerting:     return "alerting"
        case .barking:      return "dashing"      // shares row 18 with dashing
        case .spinning:     return "boxWiggle"    // shares row 8 with boxWiggle
        case .walking:      return "walking"
        case .running:      return "running"
        case .sneaking:     return "sneaking"
        case .dashing:      return "dashing"
        case .standing:     return "standing"
        case .boxIdle:      return "boxIdle"
        case .boxWiggle:    return "boxWiggle"
        case .dancing:      return "dancing"
        case .grooming:     return "grooming"
        case .lookingUp:    return "lookingUp"
        case .appearing:    return "sitting"      // lifecycle: use sitting sprite
        case .disappearing: return "sitting"      // lifecycle: use sitting sprite
        }
    }

    /// The grid config entry for this state.
    private var gridConfig: SpriteRowConfig {
        PochiSpriteGrid.config(for: gridKey)!
    }

    // MARK: - Sprite Properties (derived from grid config)

    /// Which row in the Pochi sprite sheet this state uses.
    var spriteRow: Int { gridConfig.row }

    /// Number of animation frames for this state.
    var frameCount: Int {
        switch self {
        case .appearing, .disappearing: return 1  // Single frame for lifecycle
        default: return gridConfig.frames
        }
    }

    /// Per-kind frame count — all Pochi variants share the same grid,
    /// so this just returns the base frameCount.
    func frameCount(for kind: PetKind) -> Int {
        frameCount
    }

    /// Maps a logical frame index to the actual sprite column.
    /// For rows with skipped columns, remaps logical indices to skip
    /// over the gaps defined in the grid config.
    func spriteColumn(for logicalFrame: Int) -> Int {
        let skips = gridConfig.skipColumns
        guard !skips.isEmpty else { return logicalFrame }
        // Walk through columns, skipping the ones in the skip set
        var column = 0
        var logical = 0
        while logical < logicalFrame {
            column += 1
            if !skips.contains(column) {
                logical += 1
            }
        }
        // Skip the starting column if it's in the skip set
        while skips.contains(column) {
            column += 1
        }
        return column
    }

    /// Whether this animation loops continuously.
    var loops: Bool {
        switch self {
        case .appearing, .disappearing: return false  // Lifecycle never loops
        default: return gridConfig.loops
        }
    }

    /// Scale factor for the sprite. Walking/running/movement animations
    /// use the full cell; stationary poses render slightly smaller (85%)
    /// so the visual sizes feel consistent.
    var spriteScale: CGFloat {
        switch self {
        case .walking, .running, .sneaking, .dashing, .alerting, .barking:
            return 1.0
        default:
            return 0.85
        }
    }

    /// Map a SessionStatus to the corresponding pet animation state.
    init(from status: SessionStatus) {
        switch status {
        case .idle: self = .sleeping
        case .working: self = .sitting
        case .compacting: self = .spinning
        case .waitingInput, .needsAttention: self = .alerting
        case .waitingPermission: self = .barking
        }
    }

    /// Whether the pet should be actively chasing the cursor.
    /// Identical to `isAttentionSeeking` — retained as a semantic alias
    /// for readability at call sites that care about movement vs. status.
    var isMoving: Bool { isAttentionSeeking }

    /// Whether this state represents an attention-seeking behavior.
    var isAttentionSeeking: Bool {
        switch self {
        case .alerting, .barking: return true
        default: return false
        }
    }
}
