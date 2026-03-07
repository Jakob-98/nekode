import AppKit
import Foundation
import QuartzCore

// MARK: - Movement Constants

enum PetPhysics {
    static let roamSpeed: CGFloat = 70           // pt/s when roaming (2D)
    static let attentionSpeed: CGFloat = 120     // pt/s when chasing mouse cursor
    static let idleWalkSpeed: CGFloat = 60       // pt/s when walking to rest spot
    static let runInSpeed: CGFloat = 140         // pt/s when running in from screen edge
    static let vibeWanderSpeed: CGFloat = 40     // pt/s gentle wander inside vibe zone
    static let sleepDriftSpeed: CGFloat = 12     // pt/s very slow sleeping drift
    static let acceleration: CGFloat = 300       // pt/s² how fast pet reaches max speed
    static let deceleration: CGFloat = 400       // pt/s² how fast pet stops
    static let pauseDurationMin: Double = 1      // min pause duration
    static let pauseDurationMax: Double = 3      // max pause duration
    static let personalSpace: CGFloat = 60        // min center-to-center distance between pets
    static let gatheringRadius: CGFloat = 120     // how close idle pets drift toward each other
    static let edgeMargin: CGFloat = 20          // distance from screen edges
    static let appearDuration: Double = 0.4
    static let disappearDuration: Double = 0.3
    /// How close (pts) before pet considers itself "arrived"
    static let arrivalThreshold: CGFloat = 20
    /// How close (pts) before the run-in is considered complete
    static let runInArrivalThreshold: CGFloat = 20
    /// Sensible fallback screen rect when NSScreen.main is nil
    static let fallbackScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
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

        // Don't move while dragging — pet stays where user is holding it
        guard !pet.isDragging else { return }

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
            updateIdleResting(pet, dt: dt, screenBounds: screenBounds, vibeZone: vibeZone)
        case .sleeping:
            // Sleeping pets still gently wander within the vibe zone
            updateSleepingWander(pet, dt: dt, screenBounds: screenBounds, vibeZone: vibeZone)
        default:
            // spinning, walking, running, appearing, disappearing — stationary
            pet.velocity = .zero
        }

        // Apply 2D velocity
        pet.position.x += pet.velocity.x * CGFloat(dt)
        pet.position.y += pet.velocity.y * CGFloat(dt)

        // Track idle time: accumulates while sitting, including during vibe zone
        // pauses between wanders. Only resets on state change (handled in
        // updateStateTransition) or when moving to a non-sitting state.
        if pet.state == .sitting {
            pet.idleTime += dt
        } else if pet.state != .sleeping {
            // Don't reset idle time during sleep (preserves the idle→sleep
            // transition's meaning). Reset when entering any other active state.
            pet.idleTime = 0
        }

        // Track attention escalation time
        if pet.state.isAttentionSeeking {
            pet.attentionTime += dt
        }

        // Tier 3 drowsy → transition to sleeping after 180s idle
        // (idleTime now accumulates continuously while sitting, including
        // during vibe zone wander pauses, so this will actually fire)
        if pet.state == .sitting && pet.idleTier >= 3 && pet.idleTime > 180 {
            pet.state = .sleeping
            pet.currentFrame = 0
            pet.frameAccumulator = 0
            // Reset sleep drift state so it starts fresh
            pet.sleepDriftTarget = nil
            pet.sleepDrifting = false
            pet.roamPauseUntil = CACurrentMediaTime() + Double.random(in: 20...45)
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
        let effectiveFPS = pet.state == .sleeping ? fps * 0.3 : fps
        pet.frameAccumulator += dt * effectiveFPS
        let framesToAdvance = Int(pet.frameAccumulator)
        if framesToAdvance > 0 {
            pet.frameAccumulator -= Double(framesToAdvance)
            let maxFrames = pet.visualState.frameCount(for: pet.kind)
            if pet.state.loops {
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

    // MARK: - Roaming (smooth wander with steering behavior)

    static func updateRoaming(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect,
        allPets: [PetModel] = []
    ) {
        let now = CACurrentMediaTime()

        // Check if we should pause (standing still)
        if pet.roamPauseUntil > now {
            let decel = accelerateToward(
                current: pet.velocity, desired: .zero, dt: dt
            )
            pet.velocity = decel
            return
        }

        // Pick a new desired heading periodically (every 3-8s)
        if now >= pet.roamNextDirectionChange {
            // Priority: gathering bias > edge repulsion > random
            if let gatherPt = gatheringTarget(
                for: pet, allPets: allPets
            ) {
                // Steer toward the group centroid
                let gdx = gatherPt.x - pet.position.x
                let gdy = gatherPt.y - pet.position.y
                pet.roamDesiredHeading = atan2(gdy, gdx)
            } else if let bias = edgeRepulsionHeading(
                pet.position, screenBounds: screenBounds
            ) {
                // Strong nudge toward screen center
                pet.roamDesiredHeading = bias
            } else {
                // Random desired heading
                pet.roamDesiredHeading = CGFloat.random(
                    in: 0...(2 * .pi)
                )
            }
            pet.roamNextDirectionChange = now + Double.random(in: 3...8)

            // Occasionally schedule a pause (15% chance per direction change)
            if Double.random(in: 0...1) < 0.15 {
                let pauseLen = Double.random(
                    in: PetPhysics.pauseDurationMin...PetPhysics.pauseDurationMax
                )
                pet.roamPauseUntil = now + pauseLen
            }
        }

        // Smoothly steer current heading toward desired heading
        let turnSpeed: CGFloat = 2.0  // radians/s
        let maxTurn = turnSpeed * CGFloat(dt)
        let angleDiff = normalizeAngle(
            pet.roamDesiredHeading - pet.roamHeading
        )
        if abs(angleDiff) <= maxTurn {
            pet.roamHeading = pet.roamDesiredHeading
        } else {
            pet.roamHeading += angleDiff > 0 ? maxTurn : -maxTurn
        }
        // Keep heading in [0, 2π)
        pet.roamHeading = normalizeAngle(pet.roamHeading)
        if pet.roamHeading < 0 {
            pet.roamHeading += 2 * .pi
        }

        // Desired velocity along current heading
        let desiredVel = CGPoint(
            x: cos(pet.roamHeading) * PetPhysics.roamSpeed,
            y: sin(pet.roamHeading) * PetPhysics.roamSpeed
        )

        // Accelerate smoothly toward desired velocity
        pet.velocity = accelerateToward(
            current: pet.velocity, desired: desiredVel, dt: dt
        )

        // Update facing direction with squash on direction change
        let newFacing = pet.velocity.x >= 0
        if newFacing != pet.facingRight {
            triggerSquash(pet, scaleX: 1.05, scaleY: 0.95, duration: 0.06)
        }
        pet.facingRight = newFacing
    }

    /// Returns a heading angle pointing away from nearby screen edges,
    /// or nil if the pet is safely in the interior.
    private static func edgeRepulsionHeading(
        _ pos: CGPoint, screenBounds: CGRect
    ) -> CGFloat? {
        let margin: CGFloat = 80  // Start repelling within this distance
        let minX = screenBounds.minX + PetPhysics.edgeMargin
        let maxX = screenBounds.maxX - PetPhysics.edgeMargin
        let minY = screenBounds.minY + PetPhysics.edgeMargin
        let maxY = screenBounds.maxY - PetPhysics.edgeMargin

        // Accumulate a repulsion vector from nearby edges
        var rx: CGFloat = 0
        var ry: CGFloat = 0

        if pos.x - minX < margin { rx += margin - (pos.x - minX) }
        if maxX - pos.x < margin { rx -= margin - (maxX - pos.x) }
        if pos.y - minY < margin { ry += margin - (pos.y - minY) }
        if maxY - pos.y < margin { ry -= margin - (maxY - pos.y) }

        let mag = sqrt(rx * rx + ry * ry)
        guard mag > 1 else { return nil }
        return atan2(ry, rx)
    }

    /// Normalize an angle to [-π, π].
    private static func normalizeAngle(_ angle: CGFloat) -> CGFloat {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a < -.pi { a += 2 * .pi }
        return a
    }

    // MARK: - Idle Resting (sitting/working — wanders gently in vibe zone)

    static func updateIdleResting(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect,
        vibeZone: CGRect? = nil
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
            let expandedZone = safeInset(zone, dx: -30, dy: -30)
            if pet.lastDropPosition == nil || !expandedZone.contains(pet.lastDropPosition!) {
                pet.lastDropPosition = randomPointInZone(zone)
            }

            guard let home = pet.lastDropPosition else {
                pet.velocity = .zero
                return
            }

            let dx = home.x - pet.position.x
            let dy = home.y - pet.position.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist < PetPhysics.arrivalThreshold {
                // Arrived — settle, then after a pause pick a new wander target
                if pet.velocity != .zero {
                    triggerSquash(pet, scaleX: 1.08, scaleY: 0.92, duration: 0.12)
                    spawnDust(pet)
                    pet.velocity = .zero
                    // Schedule next wander after a random pause
                    pet.roamPauseUntil = now + Double.random(in: 3...10)
                }

                // After the pause, pick a new random spot in the vibe zone
                // (idleTime continues accumulating — no reset here)
                if now >= pet.roamPauseUntil && pet.velocity == .zero {
                    pet.lastDropPosition = randomPointInZone(zone)
                }
            } else {
                // Walk toward current target
                let desiredVel = velocityToward(
                    from: pet.position, to: home,
                    speed: PetPhysics.vibeWanderSpeed
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
            if pet.velocity != .zero {
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

    /// Sleeping pets drift very slowly to a nearby point, then pause for
    /// 30-60s, then pick a new target. Uses `sleepDriftTarget` and
    /// `sleepDrifting` to avoid clobbering `lastDropPosition` (the pet's home).
    static func updateSleepingWander(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect,
        vibeZone: CGRect? = nil
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
            pet.roamPauseUntil = now + Double.random(in: 20...45)
        }

        // Pausing phase: sit still until pause timer expires
        if !pet.sleepDrifting {
            pet.velocity = .zero
            if now >= pet.roamPauseUntil {
                // Time to drift — pick a nearby point in the vibe zone
                pet.sleepDriftTarget = randomPointInZone(zone)
                pet.sleepDrifting = true
            }
            return
        }

        // Drifting phase: very slowly move toward target
        guard let target = pet.sleepDriftTarget else {
            pet.sleepDrifting = false
            pet.roamPauseUntil = now + Double.random(in: 30...60)
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
            pet.roamPauseUntil = now + Double.random(in: 30...60)
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
        let pad: CGFloat = 15
        let xMin = zone.minX + min(pad, zone.width / 2)
        let xMax = zone.maxX - min(pad, zone.width / 2)
        let yMin = zone.minY + min(pad, zone.height / 2)
        let yMax = zone.maxY - min(pad, zone.height / 2)
        return CGPoint(
            x: CGFloat.random(in: xMin...xMax),
            y: CGFloat.random(in: yMin...yMax)
        )
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
            let stopDist: CGFloat = 8
            if dist < stopDist {
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
            let stopDist: CGFloat = 8
            let speed: CGFloat = 100
            if dist < stopDist {
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: .zero, dt: dt
                )
            } else {
                let desiredVel = velocityToward(
                    from: pet.position, to: target,
                    speed: speed
                )
                pet.velocity = accelerateToward(
                    current: pet.velocity, desired: desiredVel, dt: dt
                )
            }

        default:
            // Stage 4 — Urgent: run to spaced target, bounce
            let stopDist: CGFloat = 8
            if dist < stopDist {
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
                        in: 0.6...1.0
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
            pet.bubbleTimeRemaining = Double.random(in: 2.5...4)
            // Cooldown depends on context: attention stage or idle tier
            if pet.state.isAttentionSeeking {
                switch pet.attentionStage {
                case 1: pet.bubbleCooldown = Double.random(in: 20...40)
                case 2: pet.bubbleCooldown = Double.random(in: 12...25)
                case 3: pet.bubbleCooldown = Double.random(in: 6...12)
                default: pet.bubbleCooldown = Double.random(in: 3...6)
                }
            } else {
                switch pet.idleTier {
                case 1: pet.bubbleCooldown = Double.random(in: 45...90)
                case 2: pet.bubbleCooldown = Double.random(in: 20...45)
                default: pet.bubbleCooldown = Double.random(in: 15...30)
                }
            }
        } else {
            pet.bubbleCooldown = Double.random(in: 30...60)
        }
    }

    private static func bubbleText(for pet: PetModel) -> String? {
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

        // Reset attention escalation when entering attention-seeking state
        if newState.isAttentionSeeking && !oldState.isAttentionSeeking {
            pet.attentionTime = 0
            pet.attentionBounceNext = 0
        }

        // Reset attention time when leaving attention-seeking state
        if !newState.isAttentionSeeking && oldState.isAttentionSeeking {
            pet.attentionTime = 0
        }

        // Save home position when entering attention-seeking state
        if newState.isAttentionSeeking && !oldState.isAttentionSeeking {
            pet.preChaseHome = pet.lastDropPosition
        }

        // Return to chill area when leaving attention-seeking state normally
        // (non-dismiss path, e.g. session status changed on its own — user responded).
        // Always clear hasCustomHome so the pet returns to the vibe zone, even if
        // the user had previously dragged it elsewhere. The pet is "satisfied" and
        // goes back to hang out with its friends.
        if oldState.isAttentionSeeking && !newState.isAttentionSeeking {
            if let savedHome = pet.preChaseHome {
                pet.lastDropPosition = savedHome
                pet.preChaseHome = nil
            }
            pet.hasCustomHome = false

            // Satisfied bounce — the pet got what it wanted!
            triggerSquash(pet, scaleX: 0.88, scaleY: 1.14, duration: 0.15)
            spawnDust(pet)

            // Show a brief satisfied speech bubble
            let satisfiedMessages = ["thanks!", "ok!", "on it!", "got it!", "yay!", ":3"]
            pet.activeBubbleText = satisfiedMessages.randomElement()
            pet.bubbleTimeRemaining = 2.5
            pet.bubbleCooldown = 10  // Don't immediately show another bubble
        }

        // Reset target when changing behavioral mode
        if oldState.isAttentionSeeking != newState.isAttentionSeeking
            || oldState.isMoving != newState.isMoving {
            pet.target = nil
        }

        // Reset roaming when entering a moving state
        if newState.isMoving && !oldState.isMoving {
            pet.roamPauseUntil = 0
            pet.roamNextDirectionChange = 0  // Pick new heading immediately
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

    // MARK: - Multi-Pet: Collision Resolution (2D Personal Space)

    /// Push overlapping pets apart in 2D. Each pair of pets maintains
    /// `personalSpace` distance between their centers. O(n²) pairwise —
    /// fine for the expected 3-5 pets.
    static func resolveCollisions(
        _ pets: [PetModel], minGap: CGFloat
    ) {
        guard pets.count > 1 else { return }
        for i in 0..<pets.count {
            for j in (i + 1)..<pets.count {
                let a = pets[i]
                let b = pets[j]
                // Don't push pets that are being dragged
                if a.isDragging || b.isDragging { continue }
                let dx = b.position.x - a.position.x
                let dy = b.position.y - a.position.y
                let dist = sqrt(dx * dx + dy * dy)
                guard dist < minGap && dist > 0.01 else { continue }
                let overlap = minGap - dist
                // Push each pet apart by half the overlap along their axis
                let nx = dx / dist
                let ny = dy / dist
                a.position.x -= nx * overlap / 2
                a.position.y -= ny * overlap / 2
                b.position.x += nx * overlap / 2
                b.position.y += ny * overlap / 2
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

        // Offset distance based on attention stage stop distance
        let stopDist: CGFloat
        switch pet.attentionStage {
        case 1: stopDist = 0     // Stage 1 doesn't move
        case 2: stopDist = 50
        case 3: stopDist = 30
        default: stopDist = 20
        }

        return CGPoint(
            x: mouseTarget.x + cos(angle) * stopDist,
            y: mouseTarget.y + sin(angle) * stopDist
        )
    }

    // MARK: - Multi-Pet: Gathering Bias

    /// Computes a gentle bias point that draws roaming pets toward each
    /// other. Returns the centroid of all non-roaming (sitting) pets, or
    /// nil if there are fewer than 2 sitting pets to gather around.
    static func gatheringTarget(
        for pet: PetModel, allPets: [PetModel]
    ) -> CGPoint? {
        let sitters = allPets.filter {
            $0.id != pet.id
                && $0.state == .sitting
                && $0.velocity == .zero
                && !$0.isDragging
        }
        guard !sitters.isEmpty else { return nil }

        // Centroid of sitting pets
        var cx: CGFloat = 0
        var cy: CGFloat = 0
        for s in sitters {
            cx += s.position.x
            cy += s.position.y
        }
        cx /= CGFloat(sitters.count)
        cy /= CGFloat(sitters.count)

        // Only bias if we're beyond gathering radius
        let dx = cx - pet.position.x
        let dy = cy - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > PetPhysics.gatheringRadius else { return nil }

        return CGPoint(x: cx, y: cy)
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
