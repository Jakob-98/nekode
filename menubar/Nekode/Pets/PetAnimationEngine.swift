import AppKit
import Foundation
import QuartzCore

// MARK: - Movement Constants

enum PetPhysics {

    // MARK: - User-Adjustable (backed by UserDefaults)

    /// Movement speeds (pt/s) — user-configurable via settings sliders.
    /// Each has a default, min, and max for the slider range.
    static var attentionSpeed: CGFloat { CGFloat(ud.double(forKey: Keys.attentionSpeed)).clamped(to: attentionSpeedRange) }
    static var idleWalkSpeed: CGFloat { CGFloat(ud.double(forKey: Keys.idleWalkSpeed)).clamped(to: idleWalkSpeedRange) }
    static var runInSpeed: CGFloat { CGFloat(ud.double(forKey: Keys.runInSpeed)).clamped(to: runInSpeedRange) }
    static var vibeWanderSpeed: CGFloat { CGFloat(ud.double(forKey: Keys.vibeWanderSpeed)).clamped(to: vibeWanderSpeedRange) }
    static var sleepDriftSpeed: CGFloat { CGFloat(ud.double(forKey: Keys.sleepDriftSpeed)).clamped(to: sleepDriftSpeedRange) }

    /// Idle-to-sleep onset threshold (seconds of idleTime before falling asleep).
    static var sleepOnsetTime: Double { ud.double(forKey: Keys.sleepOnsetTime).clamped(to: sleepOnsetRange) }

    // Ranges for sliders
    static let attentionSpeedRange: ClosedRange<CGFloat> = 60...300
    static let idleWalkSpeedRange: ClosedRange<CGFloat> = 30...180
    static let runInSpeedRange: ClosedRange<CGFloat> = 60...280
    static let vibeWanderSpeedRange: ClosedRange<CGFloat> = 10...100
    static let sleepDriftSpeedRange: ClosedRange<CGFloat> = 4...30
    static let sleepOnsetRange: ClosedRange<Double> = 30...600

    // Defaults (registered via registerDefaults)
    static let defaultAttentionSpeed: Double = 180
    static let defaultIdleWalkSpeed: Double = 90
    static let defaultRunInSpeed: Double = 140
    static let defaultVibeWanderSpeed: Double = 40
    static let defaultSleepDriftSpeed: Double = 12
    static let defaultSleepOnsetTime: Double = 180

    // UserDefaults keys
    enum Keys {
        static let attentionSpeed = "catAttentionSpeed"
        static let idleWalkSpeed = "catIdleWalkSpeed"
        static let runInSpeed = "catRunInSpeed"
        static let vibeWanderSpeed = "catVibeWanderSpeed"
        static let sleepDriftSpeed = "catSleepDriftSpeed"
        static let sleepOnsetTime = "catSleepOnsetTime"
    }

    /// Register defaults so sliders show correct initial values.
    static func registerDefaults() {
        ud.register(defaults: [
            Keys.attentionSpeed: defaultAttentionSpeed,
            Keys.idleWalkSpeed: defaultIdleWalkSpeed,
            Keys.runInSpeed: defaultRunInSpeed,
            Keys.vibeWanderSpeed: defaultVibeWanderSpeed,
            Keys.sleepDriftSpeed: defaultSleepDriftSpeed,
            Keys.sleepOnsetTime: defaultSleepOnsetTime,
        ])
    }

    private static let ud = UserDefaults.standard

    // MARK: - Acceleration (pt/s²)
    static let acceleration: CGFloat = 450
    static let deceleration: CGFloat = 600

    // MARK: - Attention Escalation
    /// Seconds in attention state before escalating to each stage.
    static let attentionStage2Threshold: Double = 4
    static let attentionStage3Threshold: Double = 30
    static let attentionStage4Threshold: Double = 60
    /// Speed for attention stage 3 (insistent approach).
    static let attentionInsistentSpeed: CGFloat = 150
    /// Stop distances for approach stages (pts from cursor target).
    static let attentionStopDist: CGFloat = 8
    /// Base stop distances for multi-pet arc spacing per stage.
    static let attentionBaseStopDist2: CGFloat = 50
    static let attentionBaseStopDist3: CGFloat = 30
    static let attentionBaseStopDist4: CGFloat = 20
    /// Attention bounce interval range (stage 4).
    static let attentionBounceMin: Double = 0.6
    static let attentionBounceMax: Double = 1.0

    // MARK: - Idle Tiers
    /// Seconds of zero velocity before entering each idle tier.
    static let idleTier1Threshold: Double = 5
    static let idleTier2Threshold: Double = 30
    static let idleTier3Threshold: Double = 120

    // MARK: - Spacing
    static let personalSpace: CGFloat = 60
    static let softRepulsionRadius: CGFloat = 90
    static let softRepulsionStrength: CGFloat = 120
    static let edgeMargin: CGFloat = 20
    /// Fraction of personalSpace for "too close to neighbor" target check.
    static let neighborProximityFactor: CGFloat = 0.7

    // MARK: - Lifecycle
    static let appearDuration: Double = 0.4
    static let disappearDuration: Double = 0.3

    // MARK: - Thresholds
    /// How close (pts) before pet considers itself "arrived"
    static let arrivalThreshold: CGFloat = 20
    /// How close (pts) before the run-in is considered complete
    static let runInArrivalThreshold: CGFloat = 20
    /// Speed below which velocity is snapped to zero. Prevents micro-velocities
    /// from neighbor avoidance keeping the pet in a walking animation ("flying" bug).
    static let velocitySnapThreshold: CGFloat = 2.0

    // MARK: - Hitbox & vibe zone
    /// Factor of petSize for the clickable sprite hit area.
    static let hitboxFactor: CGFloat = 0.85
    /// Vertical downshift of hitbox (factor of petSize) to align with sprite feet.
    static let hitboxDownShift: CGFloat = 0.04
    /// Base vibe zone size for 1-2 pets.
    static let vibeZoneBaseWidth: CGFloat = 200
    static let vibeZoneBaseHeight: CGFloat = 120
    /// Extra vibe zone space per pet beyond 2.
    static let vibeZoneExtraWidth: CGFloat = 60
    static let vibeZoneExtraHeight: CGFloat = 30
    /// Padding for vibe zone containment check / zone edge offsets.
    static let vibeZonePadding: CGFloat = 30
    /// Padding inside zone for random target points.
    static let zoneTargetPadding: CGFloat = 15

    // MARK: - Sleep
    /// Duration of the brief "wake" animation when a sleeping pet is dragged.
    static let sleepWakeDuration: Double = 1.2
    /// Sleep blink interval range (seconds between blinks).
    static let sleepBlinkIntervalMin: Double = 15
    static let sleepBlinkIntervalMax: Double = 30
    /// Sleep blink hold duration range.
    static let sleepBlinkDurationMin: Double = 0.4
    static let sleepBlinkDurationMax: Double = 0.6
    /// Sleep drift initial/arrival pause range.
    static let sleepDriftPauseShortMin: Double = 20
    static let sleepDriftPauseShortMax: Double = 45
    static let sleepDriftPauseLongMin: Double = 30
    static let sleepDriftPauseLongMax: Double = 60

    // MARK: - Idle Roaming
    /// Pause range after arriving at a wander target in the vibe zone.
    static let roamPauseMin: Double = 3
    static let roamPauseMax: Double = 10

    // MARK: - Speech Bubbles
    /// How long a bubble stays visible.
    static let bubbleDisplayMin: Double = 2.5
    static let bubbleDisplayMax: Double = 4.0
    /// Cooldown ranges per attention stage.
    static let bubbleCooldownAttention1: ClosedRange<Double> = 20...40
    static let bubbleCooldownAttention2: ClosedRange<Double> = 12...25
    static let bubbleCooldownAttention3: ClosedRange<Double> = 6...12
    static let bubbleCooldownAttention4: ClosedRange<Double> = 3...6
    /// Cooldown ranges per idle tier.
    static let bubbleCooldownIdle1: ClosedRange<Double> = 45...90
    static let bubbleCooldownIdle2: ClosedRange<Double> = 20...45
    static let bubbleCooldownIdleDefault: ClosedRange<Double> = 15...30
    /// Default cooldown when no bubble text generated.
    static let bubbleCooldownEmpty: ClosedRange<Double> = 30...60
    /// Initial bubble cooldown on spawn.
    static let bubbleInitialCooldown: Double = 15

    // MARK: - Celebration
    static let celebrationDuration: Double = 1.2
    static let celebrationBubbleDuration: Double = 2.5
    static let celebrationBubbleCooldown: Double = 10

    // MARK: - Animation
    /// Sleeping animation FPS multiplier (fraction of normal FPS).
    static let sleepFPSMultiplier: Double = 0.3
    /// Animation tick rate (seconds per frame).
    static let tickInterval: Double = 1.0 / 15.0
    /// Maximum delta time cap to prevent physics jumps.
    static let dtCap: Double = 0.1

    // MARK: - Collision
    /// Fraction of overlap corrected per tick in collision resolution.
    /// Lower = gentler (soft repulsion handles the rest).
    static let collisionCorrectionFraction: CGFloat = 0.3
    /// Fraction of gap used for attention-seeking collision.
    static let attentionGapFraction: CGFloat = 0.5

    // MARK: - License Nudge
    /// Denominator for 1-in-N chance of showing license nudge bubble.
    static let licenseNudgeChance: Int = 20

    /// Sensible fallback screen rect when NSScreen.main is nil
    static let fallbackScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
}

// MARK: - Comparable Clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Animation Engine

/// Stateless utility that computes pet updates. Called by PetManager each tick.
@MainActor
enum PetAnimationEngine {

    /// Advance one tick. Mutates the PetModel in place.
    /// `allPets` provides sibling awareness for spacing and gathering.
    /// `vibeZone` is the shared hangout area pets wander within.
    static func tick(
        _ pet: PetModel, dt: TimeInterval,
        screenBounds: CGRect, allPets: [PetModel] = [],
        vibeZone: CGRect? = nil
    ) {
        // Handle appear/disappear lifecycle
        if pet.isAppearing {
            pet.opacity = min(1.0, pet.opacity + dt / PetPhysics.appearDuration)
            pet.scale = min(1.0, pet.scale + dt / PetPhysics.appearDuration)
            if pet.opacity >= 1.0 {
                pet.isAppearing = false
                pet.opacity = 1.0
                pet.scale = 1.0
            }
            return
        }

        if pet.isDisappearing {
            pet.opacity = max(
                0.0, pet.opacity - dt / PetPhysics.disappearDuration
            )
            pet.scale = max(
                0.3, pet.scale - dt / PetPhysics.disappearDuration
            )
            if pet.opacity <= 0.0 {
                pet.shouldRemove = true
            }
            return
        }

        // Don't move while dragging — pet stays where user is holding it.
        // Exception: tick the wake animation so the sprite visibly stirs.
        if pet.isDragging {
            if pet.sleepWakeTimeRemaining > 0 {
                pet.sleepWakeTimeRemaining -= dt
                stepAnimation(pet, dt: dt)
                pet.breathAccumulator += dt
            }
            return
        }

        // Tick sleep-wake timer (counts down after drop too)
        if pet.sleepWakeTimeRemaining > 0 {
            pet.sleepWakeTimeRemaining -= dt
            if pet.sleepWakeTimeRemaining <= 0 {
                pet.sleepWakeTimeRemaining = 0
                pet.currentFrame = 0
                pet.frameAccumulator = 0
            }
        }

        // Tick celebration dance timer
        if pet.isCelebrating {
            pet.celebrationTimeRemaining -= dt
            if pet.celebrationTimeRemaining <= 0 {
                pet.isCelebrating = false
                pet.currentFrame = 0
                pet.frameAccumulator = 0
            } else {
                // During celebration: stand still, just animate the dance sprite
                pet.velocity = .zero
                stepAnimation(pet, dt: dt)
                pet.breathAccumulator += dt
                updateSquash(pet, dt: dt)
                updateDustParticles(pet, dt: dt)
                updateSpeechBubble(pet, dt: dt)
                return
            }
        }

        // Handle run-in from screen edge (spawn animation)
        // If an attention-seeking state arrived during run-in, abort run-in
        // so the pet can chase the cursor immediately.
        if pet.isRunningIn {
            if pet.state.isAttentionSeeking {
                pet.isRunningIn = false
                pet.runInTarget = nil
                pet.velocity = .zero
            } else {
                updateRunIn(pet, dt: dt, screenBounds: screenBounds)
                // Apply velocity, advance sprite, update particles even during run-in
                pet.position.x += pet.velocity.x * CGFloat(dt)
                pet.position.y += pet.velocity.y * CGFloat(dt)
                stepAnimation(pet, dt: dt)
                pet.breathAccumulator += dt
                updateSquash(pet, dt: dt)
                updateDustParticles(pet, dt: dt)
                return
            }
        }

        // Movement based on state
        switch pet.state {
        case .alerting, .barking:
            updateAttentionSeeking(
                pet, dt: dt, screenBounds: screenBounds,
                allPets: allPets
            )
        case .sitting:
            updateIdleResting(pet, dt: dt, screenBounds: screenBounds, vibeZone: vibeZone, allPets: allPets)
        case .sleeping:
            // Sleeping pets still gently wander within the vibe zone
            updateSleepingWander(pet, dt: dt, screenBounds: screenBounds, vibeZone: vibeZone, allPets: allPets)
            // Random sparse blink: briefly hold on frame 0 (eyes open)
            updateSleepBlink(pet, dt: dt)
        default:
            // spinning, walking, running, appearing, disappearing — stationary
            pet.velocity = .zero
        }

        // Apply 2D velocity — with soft neighbor avoidance blended in
        applyNeighborAvoidance(pet, dt: dt, allPets: allPets)

        // Snap micro-velocities to zero so residual avoidance forces don't
        // keep the pet stuck in a walking animation (the "flying" bug).
        let speed = sqrt(pet.velocity.x * pet.velocity.x + pet.velocity.y * pet.velocity.y)
        if speed > 0 && speed < PetPhysics.velocitySnapThreshold {
            pet.velocity = .zero
        }

        pet.position.x += pet.velocity.x * CGFloat(dt)
        pet.position.y += pet.velocity.y * CGFloat(dt)

        // Track idle time: accumulates while sitting, including during vibe zone
        // pauses between wanders. Only resets on state change (handled in
        // updateStateTransition) or when moving to a non-sitting state.
        if pet.state == .sitting {
            pet.idleTime += dt

            // Cycle idle animation when sitting and stationary.
            // facingRight is NOT touched here — the pet keeps facing
            // whichever direction it was last walking.
            if speed < PetPhysics.velocitySnapThreshold {
                pet.idleAnimationTimer -= dt
                if pet.idleAnimationTimer <= 0 {
                    let oldIndex = pet.idleAnimationIndex
                    pet.idleAnimationIndex = (pet.idleAnimationIndex + 1) % PetModel.idleAnimations.count
                    // Reset frame when switching to a new idle animation
                    if oldIndex != pet.idleAnimationIndex {
                        pet.currentFrame = 0
                        pet.frameAccumulator = 0
                    }
                    let nextAnim = PetModel.idleAnimations[pet.idleAnimationIndex % PetModel.idleAnimations.count]
                    pet.idleAnimationTimer = PetModel.idleDuration(for: nextAnim)
                }
            }
        } else if pet.state != .sleeping {
            // Don't reset idle time during sleep (preserves the idle→sleep
            // transition's meaning). Reset when entering any other active state.
            pet.idleTime = 0
        }

        // Track attention escalation time
        if pet.state.isAttentionSeeking {
            pet.attentionTime += dt
        }

        // Tier 3 drowsy → transition to sleeping after sleepOnsetTime idle
        // (idleTime now accumulates continuously while sitting, including
        // during vibe zone wander pauses, so this will actually fire)
        if pet.state == .sitting && pet.idleTier >= 3 && pet.idleTime > PetPhysics.sleepOnsetTime {
            pet.state = .sleeping
            pet.currentFrame = 0
            pet.frameAccumulator = 0
            // Reset sleep drift state so it starts fresh
            pet.sleepDriftTarget = nil
            pet.sleepDrifting = false
            pet.roamPauseUntil = CACurrentMediaTime() + Double.random(in: PetPhysics.sleepDriftPauseShortMin...PetPhysics.sleepDriftPauseShortMax)
        }

        // Clamp to screen bounds (both X and Y)
        clampToScreen(pet, screenBounds: screenBounds)

        // Advance sprite frame
        stepAnimation(pet, dt: dt)

        // Update breathing bob (always ticks, even while moving)
        pet.breathAccumulator += dt

        // Update squash/stretch decay
        updateSquash(pet, dt: dt)

        // Update dust particles
        updateDustParticles(pet, dt: dt)

        // Update Zzz particles (sleeping pets)
        updateZzzParticles(pet, dt: dt)

        // Update speech bubbles
        updateSpeechBubble(pet, dt: dt)
    }

    // MARK: - Animation Frame

    static func stepAnimation(_ pet: PetModel, dt: TimeInterval) {
        let fps = pet.kind.animationFPS
        // Use slower FPS for sleeping to make it look restful
        let effectiveFPS = pet.state == .sleeping ? fps * PetPhysics.sleepFPSMultiplier : fps
        pet.frameAccumulator += dt * effectiveFPS
        let framesToAdvance = Int(pet.frameAccumulator)
        if framesToAdvance > 0 {
            pet.frameAccumulator -= Double(framesToAdvance)
            let visual = pet.visualState
            let maxFrames = visual.frameCount(for: pet.kind)
            if visual.loops {
                pet.currentFrame = (
                    pet.currentFrame + framesToAdvance
                ) % maxFrames
            } else {
                pet.currentFrame = min(
                    pet.currentFrame + framesToAdvance, maxFrames - 1
                )
            }
        }
    }

    // MARK: - Run-In (spawn from right edge)

    /// Pet runs in from the right edge of the screen toward its run-in target.
    /// Uses running animation, then transitions to normal state on arrival.
    static func updateRunIn(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect
    ) {
        guard let target = pet.runInTarget else {
            pet.isRunningIn = false
            return
        }

        let dx = target.x - pet.position.x
        let dy = target.y - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < PetPhysics.runInArrivalThreshold {
            // Arrived! End run-in
            pet.isRunningIn = false
            pet.runInTarget = nil
            pet.velocity = .zero
            pet.position = target
            triggerSquash(pet, scaleX: 1.12, scaleY: 0.88, duration: 0.12)
            spawnDust(pet)
            return
        }

        // Run toward target
        let desiredVel = velocityToward(
            from: pet.position, to: target,
            speed: PetPhysics.runInSpeed
        )
        pet.velocity = accelerateToward(
            current: pet.velocity, desired: desiredVel, dt: dt
        )
        pet.facingRight = dx > 0
    }

    // MARK: - Idle Resting (sitting/working — wanders gently in vibe zone)

    static func updateIdleResting(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect,
        vibeZone: CGRect? = nil, allPets: [PetModel] = []
    ) {
        // If pet has a custom home (user dragged it), walk toward that home
        if pet.hasCustomHome {
            guard let home = pet.lastDropPosition else {
                pet.velocity = .zero
                return
            }
            walkTowardPoint(pet, target: home, dt: dt)
            return
        }

        // Vibe zone wandering: pick a new spot within the zone periodically
        if let zone = vibeZone {
            let now = CACurrentMediaTime()

            // If pet has no home or home is outside the vibe zone, pick a new one
            let expandedZone = safeInset(zone, dx: -PetPhysics.vibeZonePadding, dy: -PetPhysics.vibeZonePadding)
            if pet.lastDropPosition == nil || !expandedZone.contains(pet.lastDropPosition!) {
                pet.lastDropPosition = randomPointInZoneAvoiding(zone, pet: pet, allPets: allPets)
            }

            guard let home = pet.lastDropPosition else {
                pet.velocity = .zero
                return
            }

            let dx = home.x - pet.position.x
            let dy = home.y - pet.position.y
            let dist = sqrt(dx * dx + dy * dy)

            // Use a larger threshold for "close enough" when the pet is already
            // stationary — this prevents collision pushes from immediately
            // triggering a walk-back (the left/right oscillation bug).
            // A pet that's sitting still tolerates being up to personalSpace
            // away from its target; a pet that's actively walking uses the
            // normal tight threshold.
            let currentSpeed = sqrt(pet.velocity.x * pet.velocity.x + pet.velocity.y * pet.velocity.y)
            let isStationary = currentSpeed < PetPhysics.velocitySnapThreshold
            let effectiveThreshold = isStationary
                ? PetPhysics.personalSpace
                : PetPhysics.arrivalThreshold

            if dist < effectiveThreshold {
                // Arrived or close enough — settle
                if !isStationary {
                    triggerSquash(pet, scaleX: 1.08, scaleY: 0.92, duration: 0.12)
                    spawnDust(pet)
                    pet.velocity = .zero
                    // Reset idle animation frame on arrival (visual state changes)
                    pet.currentFrame = 0
                    pet.frameAccumulator = 0
                    // Schedule next wander after a random pause
                    pet.roamPauseUntil = now + Double.random(in: PetPhysics.roamPauseMin...PetPhysics.roamPauseMax)
                    // Clear return-to-zone flag on arrival
                    pet.isReturningToZone = false
                }

                // If collision pushed us away, accept the new position as home
                // so we don't walk back into the neighbor. Only snap when
                // stationary and drift is within personalSpace.
                if isStationary && dist > PetPhysics.arrivalThreshold {
                    pet.lastDropPosition = pet.position
                }

                // After the pause, pick a new random spot in the vibe zone
                // (idleTime continues accumulating — no reset here)
                if now >= pet.roamPauseUntil && isStationary {
                    pet.lastDropPosition = randomPointInZoneAvoiding(zone, pet: pet, allPets: allPets)
                }
            } else {
                // Walk toward current target — but first check if the target
                // is too close to a neighbor; if so, pick a new one to avoid
                // walking straight into another pet.
                let tooCloseToNeighbor = allPets.contains { other in
                    guard other.id != pet.id, !other.isDragging else { return false }
                    let ndx = home.x - other.position.x
                    let ndy = home.y - other.position.y
                    return sqrt(ndx * ndx + ndy * ndy) < PetPhysics.personalSpace * PetPhysics.neighborProximityFactor
                }
                if tooCloseToNeighbor {
                    pet.lastDropPosition = randomPointInZoneAvoiding(zone, pet: pet, allPets: allPets)
                    // Don't start walking yet — will re-evaluate next tick
                    pet.velocity = .zero
                    return
                }

                let moveSpeed: CGFloat
                if pet.isReturningToZone {
                    moveSpeed = PetPhysics.attentionSpeed   // Fast return (e.g. "Return to Vibe Zone" button)
                } else if !zone.contains(pet.position) {
                    moveSpeed = PetPhysics.idleWalkSpeed    // Walking back from outside zone (e.g. after attention)
                } else {
                    moveSpeed = PetPhysics.vibeWanderSpeed  // Gentle roaming inside zone
                }
                let desiredVel = velocityToward(
                    from: pet.position, to: home,
                    speed: moveSpeed
                )
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: desiredVel, dt: dt
                )
                pet.facingRight = dx > 0
            }
            return
        }

        // Fallback: no vibe zone, use legacy home behavior
        guard let home = pet.lastDropPosition else {
            pet.velocity = .zero
            return
        }
        walkTowardPoint(pet, target: home, dt: dt)
    }

    /// Walk a pet toward a specific point at idle speed.
    private static func walkTowardPoint(
        _ pet: PetModel, target: CGPoint, dt: TimeInterval
    ) {
        let dx = target.x - pet.position.x
        let dy = target.y - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < PetPhysics.arrivalThreshold {
            let currentSpeed = sqrt(pet.velocity.x * pet.velocity.x + pet.velocity.y * pet.velocity.y)
            if currentSpeed >= PetPhysics.velocitySnapThreshold {
                triggerSquash(pet, scaleX: 1.08, scaleY: 0.92, duration: 0.12)
                spawnDust(pet)
            }
            pet.velocity = .zero
        } else {
            let desiredVel = velocityToward(
                from: pet.position, to: target,
                speed: PetPhysics.idleWalkSpeed
            )
            pet.velocity = accelerateToward(
                current: pet.velocity, desired: desiredVel, dt: dt
            )
            pet.facingRight = dx > 0
        }
    }

    // MARK: - Sleeping Wander (gentle drift within vibe zone)

    /// Randomly trigger a brief blink during sleep: hold on frame 0 (row 3)
    /// which looks like the cat briefly opening its eyes. Fires sparingly
    /// every ~15-30s and lasts about 0.4-0.6s.
    static func updateSleepBlink(_ pet: PetModel, dt: TimeInterval) {
        let now = CACurrentMediaTime()

        if pet.sleepBlinking {
            pet.sleepBlinkTimeRemaining -= dt
            if pet.sleepBlinkTimeRemaining <= 0 {
                pet.sleepBlinking = false
                // Let the normal animation resume from wherever it was
            } else {
                // Pin to frame 0 while blinking
                pet.currentFrame = 0
                pet.frameAccumulator = 0
            }
            return
        }

        // Only blink while stationary (not drifting) and not waking
        let blinkSpeed = sqrt(pet.velocity.x * pet.velocity.x + pet.velocity.y * pet.velocity.y)
        guard blinkSpeed < PetPhysics.velocitySnapThreshold, pet.sleepWakeTimeRemaining <= 0 else { return }

        // Schedule first blink
        if pet.sleepBlinkNext == 0 {
            pet.sleepBlinkNext = now + Double.random(in: PetPhysics.sleepBlinkIntervalMin...PetPhysics.sleepBlinkIntervalMax)
        }

        if now >= pet.sleepBlinkNext {
            pet.sleepBlinking = true
            pet.sleepBlinkTimeRemaining = Double.random(in: PetPhysics.sleepBlinkDurationMin...PetPhysics.sleepBlinkDurationMax)
            pet.currentFrame = 0
            pet.frameAccumulator = 0
            pet.sleepBlinkNext = now + Double.random(in: PetPhysics.sleepBlinkIntervalMin...PetPhysics.sleepBlinkIntervalMax)
        }
    }

    /// Sleeping pets drift very slowly to a nearby point, then pause for
    /// 30-60s, then pick a new target. Uses `sleepDriftTarget` and
    /// `sleepDrifting` to avoid clobbering `lastDropPosition` (the pet's home).
    static func updateSleepingWander(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect,
        vibeZone: CGRect? = nil, allPets: [PetModel] = []
    ) {
        // Sleeping pets don't move if they have a custom home
        guard !pet.hasCustomHome else {
            pet.velocity = .zero
            return
        }
        // No vibe zone = no movement while sleeping (legacy)
        guard let zone = vibeZone else {
            pet.velocity = .zero
            return
        }

        let now = CACurrentMediaTime()

        // Initialize pause timer on first entry
        if pet.roamPauseUntil == 0 {
            pet.roamPauseUntil = now + Double.random(in: PetPhysics.sleepDriftPauseShortMin...PetPhysics.sleepDriftPauseShortMax)
        }

        // Pausing phase: sit still until pause timer expires
        if !pet.sleepDrifting {
            pet.velocity = .zero
            if now >= pet.roamPauseUntil {
                // Time to drift — pick a nearby point avoiding other pets
                pet.sleepDriftTarget = randomPointInZoneAvoiding(zone, pet: pet, allPets: allPets)
                pet.sleepDrifting = true
            }
            return
        }

        // Drifting phase: very slowly move toward target
        guard let target = pet.sleepDriftTarget else {
            pet.sleepDrifting = false
            pet.roamPauseUntil = now + Double.random(in: PetPhysics.sleepDriftPauseLongMin...PetPhysics.sleepDriftPauseLongMax)
            pet.velocity = .zero
            return
        }

        let dx = target.x - pet.position.x
        let dy = target.y - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < PetPhysics.arrivalThreshold {
            // Arrived — stop drifting, start a new pause
            pet.velocity = .zero
            pet.sleepDrifting = false
            pet.sleepDriftTarget = nil
            pet.roamPauseUntil = now + Double.random(in: PetPhysics.sleepDriftPauseLongMin...PetPhysics.sleepDriftPauseLongMax)
        } else {
            let desiredVel = velocityToward(
                from: pet.position, to: target,
                speed: PetPhysics.sleepDriftSpeed
            )
            pet.velocity = accelerateToward(
                current: pet.velocity, desired: desiredVel, dt: dt
            )
        }
    }

    /// Pick a random point inside a CGRect with some padding.
    /// Safe for zones of any size — clamps padding so the range is always valid.
    private static func randomPointInZone(_ zone: CGRect) -> CGPoint {
        let pad = PetPhysics.zoneTargetPadding
        let xMin = zone.minX + min(pad, zone.width / 2)
        let xMax = zone.maxX - min(pad, zone.width / 2)
        let yMin = zone.minY + min(pad, zone.height / 2)
        let yMax = zone.maxY - min(pad, zone.height / 2)
        return CGPoint(
            x: CGFloat.random(in: xMin...xMax),
            y: CGFloat.random(in: yMin...yMax)
        )
    }

    /// Pick a random point in the zone that's at least `personalSpace` away
    /// from all other pets' positions and targets. Falls back to a basic
    /// random point after a few attempts to avoid infinite loops.
    private static func randomPointInZoneAvoiding(
        _ zone: CGRect, pet: PetModel, allPets: [PetModel]
    ) -> CGPoint {
        let others = allPets.filter { $0.id != pet.id && !$0.isDragging }
        let minDist = PetPhysics.personalSpace

        for _ in 0..<8 {
            let candidate = randomPointInZone(zone)
            let tooClose = others.contains { other in
                // Check against both current position and wander target
                let dxP = candidate.x - other.position.x
                let dyP = candidate.y - other.position.y
                if sqrt(dxP * dxP + dyP * dyP) < minDist { return true }
                if let target = other.lastDropPosition {
                    let dxT = candidate.x - target.x
                    let dyT = candidate.y - target.y
                    if sqrt(dxT * dxT + dyT * dyT) < minDist { return true }
                }
                return false
            }
            if !tooClose { return candidate }
        }
        // Fallback: just return a random point (zone may be too small to avoid everyone)
        return randomPointInZone(zone)
    }

    /// Safe inset that never produces a degenerate (negative-size) rect.
    /// Positive dx/dy shrink the rect; negative expand it.
    private static func safeInset(_ rect: CGRect, dx: CGFloat, dy: CGFloat) -> CGRect {
        let inset = rect.insetBy(dx: dx, dy: dy)
        // If the inset collapsed the rect, return the original
        guard inset.width > 0 && inset.height > 0 else { return rect }
        return inset
    }

    // MARK: - Attention Seeking (4-stage escalation)

    static func updateAttentionSeeking(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect,
        allPets: [PetModel] = []
    ) {
        let mouse = NSEvent.mouseLocation
        let clampedX = max(
            screenBounds.minX + PetPhysics.edgeMargin,
            min(screenBounds.maxX - PetPhysics.edgeMargin, mouse.x)
        )
        let clampedY = max(
            screenBounds.minY + PetPhysics.edgeMargin,
            min(screenBounds.maxY - PetPhysics.edgeMargin, mouse.y)
        )
        let mouseTarget = CGPoint(x: clampedX, y: clampedY)

        // When multiple pets seek attention, spread them around the cursor
        let target = attentionTarget(
            for: pet, allPets: allPets, mouseTarget: mouseTarget
        )
        pet.target = target

        let dx = target.x - pet.position.x
        let dy = target.y - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)

        // Face the cursor (not the offset target) for natural look
        pet.facingRight = (mouseTarget.x - pet.position.x) > 0

        let stage = pet.attentionStage

        switch stage {
        case 1:
            // Perk up: stay at home, just face the cursor
            pet.velocity = accelerateToward(
                current: pet.velocity, desired: .zero, dt: dt
            )

        case 2:
            // Approach: walk toward spaced target, stop when close
            if dist < PetPhysics.attentionStopDist {
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: .zero, dt: dt
                )
            } else {
                let desiredVel = velocityToward(
                    from: pet.position, to: target,
                    speed: PetPhysics.idleWalkSpeed
                )
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: desiredVel, dt: dt
                )
            }

        case 3:
            // Insistent: faster approach to spaced target
            if dist < PetPhysics.attentionStopDist {
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: .zero, dt: dt
                )
            } else {
                let desiredVel = velocityToward(
                    from: pet.position, to: target,
                    speed: PetPhysics.attentionInsistentSpeed
                )
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: desiredVel, dt: dt
                )
            }

        default:
            // Stage 4 — Urgent: run to spaced target, bounce
            if dist < PetPhysics.attentionStopDist {
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: .zero, dt: dt
                )
                // Bounce in place every ~0.8s
                let now = CACurrentMediaTime()
                if now >= pet.attentionBounceNext {
                    triggerSquash(
                        pet, scaleX: 0.9, scaleY: 1.12,
                        duration: 0.1
                    )
                    pet.attentionBounceNext = now + Double.random(
                        in: PetPhysics.attentionBounceMin...PetPhysics.attentionBounceMax
                    )
                }
            } else {
                let desiredVel = velocityToward(
                    from: pet.position, to: target,
                    speed: PetPhysics.attentionSpeed
                )
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: desiredVel, dt: dt
                )
            }
        }
    }

    // MARK: - Speech Bubbles

    static func updateSpeechBubble(_ pet: PetModel, dt: TimeInterval) {
        // Tick down active bubble
        if pet.bubbleTimeRemaining > 0 {
            pet.bubbleTimeRemaining -= dt
            if pet.bubbleTimeRemaining <= 0 {
                pet.activeBubbleText = nil
            }
            return
        }

        // Check if it's time for a new bubble
        pet.bubbleCooldown -= dt
        if pet.bubbleCooldown > 0 { return }

        // Pick a contextual bubble based on state
        let text = bubbleText(for: pet)
        if let text {
            pet.activeBubbleText = text
            pet.bubbleTimeRemaining = Double.random(in: PetPhysics.bubbleDisplayMin...PetPhysics.bubbleDisplayMax)
            // Cooldown depends on context: attention stage or idle tier
            if pet.state.isAttentionSeeking {
                switch pet.attentionStage {
                case 1: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownAttention1)
                case 2: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownAttention2)
                case 3: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownAttention3)
                default: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownAttention4)
                }
            } else {
                switch pet.idleTier {
                case 1: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownIdle1)
                case 2: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownIdle2)
                default: pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownIdleDefault)
                }
            }
        } else {
            pet.bubbleCooldown = Double.random(in: PetPhysics.bubbleCooldownEmpty)
        }
    }

    private static func bubbleText(for pet: PetModel) -> String? {
        // 1-in-20 chance: playful license nudge for unlicensed users
        if !LicenseManager.shared.status.isLicensed && Int.random(in: 0..<PetPhysics.licenseNudgeChance) == 0 {
            return licenseNudge()
        }

        switch pet.state {
        case .sitting:
            // Tier-aware idle messages
            switch pet.idleTier {
            case 1:
                // Attentive: show tool activity or focused messages
                if let text = toolBubble(for: pet.session) {
                    return text
                }
                return ["coding...", "thinking...", "focused"].randomElement()
            case 2:
                // Bored: fidgety messages, still shows tool activity
                if let text = toolBubble(for: pet.session) {
                    return text
                }
                return [
                    "still coding...", "hmm...", "*yawn*",
                    "stretching...", "bored...",
                ].randomElement()
            default:
                // Drowsy: sleepy messages
                return [
                    "sleepy...", "zzz...", "*nods off*",
                    "so tired...", "...",
                ].randomElement()
            }
        case .sleeping:
            return nil  // Zzz particles handle sleep visuals
        case .alerting:
            // Stage-aware attention messages
            switch pet.attentionStage {
            case 1:
                return pet.session.notificationMessage
                    .map { String($0.prefix(20)) } ?? "?"
            case 2:
                return pet.session.notificationMessage
                    .map { String($0.prefix(20)) } ?? "need input"
            case 3:
                return ["hey!", "over here!", "need input"].randomElement()
            default:
                return "!!"
            }
        case .barking:
            switch pet.attentionStage {
            case 1: return "?"
            case 2: return "approve?"
            case 3: return "approve!!"
            default: return "!!!"
            }
        case .spinning:
            return "compacting..."
        default:
            return nil
        }
    }

    /// Playful purchase reminder messages shown by pets (1-in-20 chance).
    private static func licenseNudge() -> String {
        [
            "buy me a license?",
            "I want a home...",
            "support my dev?",
            "adopt me! $9.99",
            "pls license me",
            "I work for free!",
            "treat your dev?",
            "license = love",
        ].randomElement()!
    }

    /// Short bubble text from the session's current tool activity.
    private static func toolBubble(for session: Session) -> String? {
        guard let tool = session.lastTool else { return nil }
        let detail = session.lastToolDetail
        switch tool.lowercased() {
        case "bash":
            return detail.map { "$ \(String($0.prefix(18)))" } ?? "running..."
        case "edit":
            return detail.map { "editing \(fileName($0))" } ?? "editing..."
        case "write":
            return detail.map { "writing \(fileName($0))" } ?? "writing..."
        case "read":
            return detail.map { "reading \(fileName($0))" } ?? "reading..."
        case "grep", "glob":
            return "searching..."
        case "task":
            return "delegating..."
        case "webfetch", "websearch":
            return "browsing..."
        default:
            return "\(tool.lowercased())..."
        }
    }

    private static func fileName(_ path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        return String(name.prefix(14))
    }

    // MARK: - Squash/Stretch

    /// Ease squash/stretch back to 1.0 over time.
    static func updateSquash(_ pet: PetModel, dt: TimeInterval) {
        guard pet.squashTimeRemaining > 0 else { return }
        pet.squashTimeRemaining -= dt
        if pet.squashTimeRemaining <= 0 {
            pet.scaleX = 1.0
            pet.scaleY = 1.0
            pet.squashTimeRemaining = 0
        } else {
            // Linear ease back toward 1.0 using the original duration
            let duration = max(pet.squashDuration, 0.01) // Avoid division by zero
            let progress = 1.0 - pet.squashTimeRemaining / duration
            let t = CGFloat(min(max(progress, 0), 1))
            pet.scaleX = pet.squashTargetX + (1.0 - pet.squashTargetX) * t
            pet.scaleY = pet.squashTargetY + (1.0 - pet.squashTargetY) * t
        }
    }

    /// Trigger a squash/stretch effect on the pet.
    static func triggerSquash(
        _ pet: PetModel, scaleX: CGFloat, scaleY: CGFloat, duration: Double
    ) {
        pet.scaleX = scaleX
        pet.scaleY = scaleY
        pet.squashTargetX = scaleX
        pet.squashTargetY = scaleY
        pet.squashDuration = duration
        pet.squashTimeRemaining = duration
    }

    // MARK: - Dust Particles

    /// Update dust particle ages and remove expired ones.
    static func updateDustParticles(_ pet: PetModel, dt: TimeInterval) {
        guard !pet.dustParticles.isEmpty else { return }
        pet.dustParticles = pet.dustParticles.compactMap { particle in
            var p = particle
            p.age += dt
            if p.age >= p.lifetime { return nil }
            // Fade out and drift upward
            let progress = p.age / p.lifetime
            p.opacity = 1.0 - progress
            p.y -= CGFloat(dt) * 20  // Drift up
            p.size *= (1.0 + CGFloat(dt) * 0.5)  // Expand slightly
            return p
        }
    }

    /// Spawn 3-5 dust puffs at the pet's feet.
    static func spawnDust(_ pet: PetModel) {
        let count = Int.random(in: 3...5)
        for _ in 0..<count {
            let particle = PetModel.DustParticle(
                x: CGFloat.random(in: -8...8),
                y: CGFloat.random(in: -2...4),
                opacity: 1.0,
                size: CGFloat.random(in: 3...6),
                lifetime: Double.random(in: 0.2...0.4)
            )
            pet.dustParticles.append(particle)
        }
    }

    // MARK: - Zzz Particles

    /// Update Zzz particles: age them, spawn new ones while sleeping.
    static func updateZzzParticles(_ pet: PetModel, dt: TimeInterval) {
        // Age existing particles
        if !pet.zzzParticles.isEmpty {
            pet.zzzParticles = pet.zzzParticles.compactMap { particle in
                var p = particle
                p.age += dt
                if p.age >= p.lifetime { return nil }
                let progress = p.age / p.lifetime
                // Float upward and drift slightly right
                p.y -= CGFloat(dt) * 18
                p.x += CGFloat(dt) * 6
                // Fade in for first 20%, hold, fade out for last 30%
                if progress < 0.2 {
                    p.opacity = progress / 0.2
                } else if progress > 0.7 {
                    p.opacity = (1.0 - progress) / 0.3
                } else {
                    p.opacity = 1.0
                }
                // Grow slightly as they float up
                p.size += CGFloat(dt) * 1.5
                return p
            }
        }

        // Spawn new Zzz only while sleeping
        guard pet.state == .sleeping else {
            pet.zzzParticles.removeAll()
            pet.zzzNextSpawn = 0
            return
        }

        let now = CACurrentMediaTime()
        if now >= pet.zzzNextSpawn {
            let letters = ["z", "Z", "z"]
            let particle = PetModel.ZzzParticle(
                x: CGFloat.random(in: 4...12),
                y: CGFloat.random(in: -8...(-4)),
                opacity: 0,
                size: CGFloat.random(in: 8...12),
                lifetime: Double.random(in: 2.0...3.0),
                letter: letters.randomElement()!
            )
            pet.zzzParticles.append(particle)
            pet.zzzNextSpawn = now + Double.random(in: 2...3)
        }
    }

    // MARK: - State Transitions

    static func updateStateTransition(
        _ pet: PetModel, newStatus: SessionStatus
    ) {
        // If user dismissed this status by dragging, ignore until it changes
        if let dismissed = pet.dismissedStatus {
            if newStatus == dismissed { return }
            pet.dismissedStatus = nil
        }

        let newState = PetState(from: newStatus)
        guard newState != pet.state else { return }

        let oldState = pet.state
        pet.state = newState
        pet.currentFrame = 0
        pet.frameAccumulator = 0
        pet.idleTime = 0  // Reset idle tier on any state change
        pet.idleAnimationIndex = 0  // Reset idle cycling on state change
        pet.idleAnimationTimer = PetModel.idleDuration(for: PetModel.idleAnimations[0])

        // Clear sleep-related transient state on any state change
        pet.sleepWakeTimeRemaining = 0
        pet.sleepBlinking = false
        pet.sleepBlinkTimeRemaining = 0
        pet.sleepBlinkNext = 0
        pet.isReturningToZone = false

        // Reset attention escalation and save home when entering attention-seeking state
        if newState.isAttentionSeeking && !oldState.isAttentionSeeking {
            pet.attentionTime = 0
            pet.attentionBounceNext = 0
            pet.preChaseHome = pet.lastDropPosition
        }

        // Return to chill area when leaving attention-seeking state normally
        // (non-dismiss path, e.g. session status changed on its own — user responded).
        // Always clear hasCustomHome so the pet returns to the vibe zone, even if
        // the user had previously dragged it elsewhere. The pet is "satisfied" and
        // goes back to hang out with its friends.
        if oldState.isAttentionSeeking && !newState.isAttentionSeeking {
            pet.attentionTime = 0

            if let savedHome = pet.preChaseHome {
                pet.lastDropPosition = savedHome
                pet.preChaseHome = nil
            }
            pet.hasCustomHome = false

            // Satisfied bounce — the pet got what it wanted!
            triggerSquash(pet, scaleX: 0.88, scaleY: 1.14, duration: 0.15)
            spawnDust(pet)

            // Brief celebration dance before walking back to vibe zone
            pet.isCelebrating = true
            pet.celebrationTimeRemaining = PetPhysics.celebrationDuration
            pet.velocity = .zero  // Stand still while dancing
            pet.currentFrame = 0
            pet.frameAccumulator = 0

            // Show a brief satisfied speech bubble
            let satisfiedMessages = ["thanks!", "ok!", "on it!", "got it!", "yay!", ":3"]
            pet.activeBubbleText = satisfiedMessages.randomElement()
            pet.bubbleTimeRemaining = PetPhysics.celebrationBubbleDuration
            pet.bubbleCooldown = PetPhysics.celebrationBubbleCooldown
        }

        // Reset target when changing behavioral mode
        if oldState.isAttentionSeeking != newState.isAttentionSeeking
            || oldState.isMoving != newState.isMoving {
            pet.target = nil
        }

        // Reset roaming when entering a moving state
        if newState.isMoving && !oldState.isMoving {
            pet.roamPauseUntil = 0
            pet.velocity = .zero // Will be recalculated on next tick
        }
    }

    // MARK: - Screen Clamping (2D)

    static func clampToScreen(_ pet: PetModel, screenBounds: CGRect) {
        let minX = screenBounds.minX + PetPhysics.edgeMargin
        let maxX = screenBounds.maxX - PetPhysics.edgeMargin
        let minY = screenBounds.minY + PetPhysics.edgeMargin
        let maxY = screenBounds.maxY - PetPhysics.edgeMargin
        pet.position.x = max(minX, min(maxX, pet.position.x))
        pet.position.y = max(minY, min(maxY, pet.position.y))
    }

    // MARK: - Multi-Pet: Soft Neighbor Avoidance (velocity-based)

    /// Applies a gentle steering force to the pet's velocity to avoid neighbors.
    /// Unlike collision resolution (which pushes positions after the fact),
    /// this blends smoothly into the pet's movement so there's no oscillation.
    /// The force is strongest at `personalSpace` and fades to zero at
    /// `softRepulsionRadius`.
    private static func applyNeighborAvoidance(
        _ pet: PetModel, dt: TimeInterval, allPets: [PetModel]
    ) {
        guard allPets.count > 1 else { return }
        // Don't apply avoidance to pets that are being dragged or running in
        guard !pet.isDragging, !pet.isRunningIn else { return }
        // Attention-seeking pets already have arc-based spacing
        guard !pet.state.isAttentionSeeking else { return }

        var avoidX: CGFloat = 0
        var avoidY: CGFloat = 0
        let radius = PetPhysics.softRepulsionRadius

        for other in allPets {
            guard other.id != pet.id, !other.isDragging else { continue }
            let dx = pet.position.x - other.position.x
            let dy = pet.position.y - other.position.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist < radius, dist > 0.01 else { continue }

            // Force is inversely proportional to distance:
            // At dist=0 → full strength, at dist=radius → zero
            let t = 1.0 - (dist / radius)  // 0..1
            let force = PetPhysics.softRepulsionStrength * t * t // quadratic falloff
            let nx = dx / dist
            let ny = dy / dist
            avoidX += nx * force
            avoidY += ny * force
        }

        // Apply avoidance as a velocity offset (scaled by dt for smooth integration)
        let maxAvoid = PetPhysics.softRepulsionStrength * CGFloat(dt)
        let avoidMag = sqrt(avoidX * avoidX + avoidY * avoidY)
        if avoidMag > 0.1 {
            let scale = min(maxAvoid, avoidMag * CGFloat(dt)) / max(avoidMag, 0.01)
            pet.velocity.x += avoidX * scale
            pet.velocity.y += avoidY * scale
        }
    }

    // MARK: - Multi-Pet: Collision Resolution (2D Personal Space)

    /// Push overlapping pets apart in 2D. Acts as a safety net behind the
    /// soft velocity-based avoidance. Only corrects a fraction of the overlap
    /// each tick to avoid fighting the velocity system (which causes glitching).
    /// O(n²) pairwise — fine for the expected 3-5 pets.
    static func resolveCollisions(
        _ pets: [PetModel], minGap: CGFloat
    ) {
        guard pets.count > 1 else { return }
        // Reduced gap when both pets are attention-seeking so collision
        // doesn't fight their movement toward nearby cursor targets.
        let attentionGap = minGap * PetPhysics.attentionGapFraction
        // Only correct a fraction of the overlap per tick — the soft
        // repulsion handles the rest. This prevents the oscillation where
        // position push and velocity pull fight each other.
        let correctionFraction = PetPhysics.collisionCorrectionFraction
        for i in 0..<pets.count {
            for j in (i + 1)..<pets.count {
                let a = pets[i]
                let b = pets[j]
                // Don't push pets that are being dragged
                if a.isDragging || b.isDragging { continue }
                // Use a smaller gap when both are chasing the cursor
                let bothSeeking = a.state.isAttentionSeeking
                    && b.state.isAttentionSeeking
                let effectiveGap = bothSeeking ? attentionGap : minGap
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let dist = sqrt(dx * dx + dy * dy)
                guard dist < effectiveGap && dist > 0.01 else { continue }
                let overlap = effectiveGap - dist
                // Push each pet apart by a fraction of the overlap
                let nx = dx / dist
                let ny = dy / dist
                let push = overlap * correctionFraction / 2
                a.position.x -= nx * push
                a.position.y -= ny * push
                b.position.x += nx * push
                b.position.y += ny * push
            }
        }
    }

    // MARK: - Multi-Pet: Attention Approach Spacing

    /// When multiple pets chase the cursor, assign evenly-spaced approach
    /// angles so they don't pile up on the same side. Returns the offset
    /// point for a given pet's target relative to the mouse cursor.
    ///
    /// - Parameters:
    ///   - pet: The pet to compute an offset for
    ///   - allPets: All active pets (used to find attention-seeking siblings)
    ///   - mouseTarget: The cursor position
    /// - Returns: Adjusted target point with spacing offset applied
    static func attentionTarget(
        for pet: PetModel,
        allPets: [PetModel],
        mouseTarget: CGPoint
    ) -> CGPoint {
        let seekers = allPets.filter {
            $0.state.isAttentionSeeking && !$0.isDragging
        }
        guard seekers.count > 1 else { return mouseTarget }

        // Find this pet's index among attention-seeking pets (sorted by id
        // for stable ordering)
        let sorted = seekers.sorted { $0.id < $1.id }
        guard let idx = sorted.firstIndex(where: { $0.id == pet.id })
        else { return mouseTarget }

        // Spread pets evenly around the cursor
        let count = CGFloat(sorted.count)
        let baseAngle: CGFloat = .pi   // Start from the left
        let spread: CGFloat = .pi      // Spread across 180° arc
        let angle = baseAngle
            + spread * (CGFloat(idx) / max(count - 1, 1))
            - spread / 2

        // Offset distance based on attention stage stop distance.
        // Ensure targets are far enough apart that they don't violate
        // personalSpace — otherwise collision resolution fights movement.
        let baseStopDist: CGFloat
        switch pet.attentionStage {
        case 1: baseStopDist = 0     // Stage 1 doesn't move
        case 2: baseStopDist = PetPhysics.attentionBaseStopDist2
        case 3: baseStopDist = PetPhysics.attentionBaseStopDist3
        default: baseStopDist = PetPhysics.attentionBaseStopDist4
        }

        // For n pets on a 180° arc, minimum chord between adjacent targets
        // is 2 * r * sin(halfAngle). Ensure this ≥ personalSpace.
        let minRequired: CGFloat
        if count > 1 && baseStopDist > 0 {
            let halfAngle = spread / (2 * (count - 1))
            let sinVal = sin(halfAngle)
            // r needed so that 2*r*sin(halfAngle) >= personalSpace
            minRequired = sinVal > 0.01
                ? PetPhysics.personalSpace / (2 * sinVal)
                : PetPhysics.personalSpace
        } else {
            minRequired = 0
        }
        let stopDist = max(baseStopDist, minRequired)

        return CGPoint(
            x: mouseTarget.x + cos(angle) * stopDist,
            y: mouseTarget.y + sin(angle) * stopDist
        )
    }

    // MARK: - Helpers

    /// Calculate a velocity vector toward a target point at a given speed.
    private static func velocityToward(
        from origin: CGPoint, to target: CGPoint, speed: CGFloat
    ) -> CGPoint {
        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return .zero }
        return CGPoint(x: (dx / dist) * speed, y: (dy / dist) * speed)
    }

    /// Smoothly accelerate current velocity toward desired velocity.
    /// Uses acceleration to speed up and deceleration to slow down.
    private static func accelerateToward(
        current: CGPoint, desired: CGPoint, dt: TimeInterval
    ) -> CGPoint {
        let diffX = desired.x - current.x
        let diffY = desired.y - current.y
        let diffMag = sqrt(diffX * diffX + diffY * diffY)
        guard diffMag > 0.1 else { return desired }

        // Use deceleration rate when slowing down, acceleration when speeding up
        let currentSpeed = sqrt(
            current.x * current.x + current.y * current.y
        )
        let desiredSpeed = sqrt(
            desired.x * desired.x + desired.y * desired.y
        )
        let rate = desiredSpeed < currentSpeed
            ? PetPhysics.deceleration : PetPhysics.acceleration
        let maxDelta = rate * CGFloat(dt)

        if diffMag <= maxDelta {
            return desired
        }
        return CGPoint(
            x: current.x + (diffX / diffMag) * maxDelta,
            y: current.y + (diffY / diffMag) * maxDelta
        )
    }
}
