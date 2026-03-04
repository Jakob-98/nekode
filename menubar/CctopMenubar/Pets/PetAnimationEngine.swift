import AppKit
import Foundation

// MARK: - Movement Constants

enum PetPhysics {
    static let roamSpeed: CGFloat = 70           // pt/s when roaming (2D)
    static let attentionSpeed: CGFloat = 100     // pt/s when chasing mouse cursor
    static let idleWalkSpeed: CGFloat = 50       // pt/s when walking to rest spot
    static let pauseMin: Double = 2              // min seconds between roam pauses
    static let pauseMax: Double = 8              // max seconds between roam pauses
    static let pauseDurationMin: Double = 1      // min pause duration
    static let pauseDurationMax: Double = 3      // max pause duration
    static let collisionGap: CGFloat = 20        // min distance between pets
    static let edgeMargin: CGFloat = 20          // distance from screen edges
    static let appearDuration: Double = 0.4
    static let disappearDuration: Double = 0.3
    /// How close (pts) before pet considers itself "arrived"
    static let arrivalThreshold: CGFloat = 30
    /// How close attention-seeking pets must be to mouse before stopping
    static let attentionArrivalThreshold: CGFloat = 40
}

// MARK: - Animation Engine

/// Stateless utility that computes pet updates. Called by PetManager each tick.
@MainActor
enum PetAnimationEngine {

    /// Advance one tick. Mutates the PetModel in place.
    static func tick(_ pet: PetModel, dt: TimeInterval, screenBounds: CGRect) {
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

        // Movement based on state
        switch pet.state {
        case .alerting, .barking:
            updateAttentionSeeking(pet, dt: dt, screenBounds: screenBounds)
        case .walking, .running:
            updateRoaming(pet, dt: dt, screenBounds: screenBounds)
        case .sitting:
            updateIdleResting(pet, dt: dt, screenBounds: screenBounds)
        case .sleeping:
            pet.velocity = .zero
        default:
            // spinning, appearing, disappearing — stationary
            pet.velocity = .zero
        }

        // Apply 2D velocity
        pet.position.x += pet.velocity.x * CGFloat(dt)
        pet.position.y += pet.velocity.y * CGFloat(dt)

        // Clamp to screen bounds (both X and Y)
        clampToScreen(pet, screenBounds: screenBounds)

        // Advance sprite frame
        stepAnimation(pet, dt: dt)

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

    // MARK: - Roaming (free 2D movement for walking/running states)

    static func updateRoaming(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect
    ) {
        let now = Date()

        // Check if we should pause
        if let pauseUntil = pet.roamPauseUntil {
            if now < pauseUntil {
                pet.velocity = .zero
                return
            }
            pet.roamPauseUntil = nil
        }

        // If velocity is zero (just started or after pause), pick a 2D target
        if pet.velocity == .zero {
            let minX = screenBounds.minX + PetPhysics.edgeMargin
            let maxX = screenBounds.maxX - PetPhysics.edgeMargin
            let minY = screenBounds.minY + PetPhysics.edgeMargin
            let maxY = screenBounds.maxY - PetPhysics.edgeMargin
            let targetX = CGFloat.random(in: minX...maxX)
            let targetY = CGFloat.random(in: minY...maxY)
            pet.target = CGPoint(x: targetX, y: targetY)

            // Set velocity toward target
            let vel = velocityToward(
                from: pet.position, to: pet.target!,
                speed: PetPhysics.roamSpeed
            )
            pet.velocity = vel
            pet.facingRight = vel.x >= 0

            // Schedule a random pause after arriving (or after a timeout)
            let pauseIn = Double.random(in: PetPhysics.pauseMin...PetPhysics.pauseMax)
            let pauseLen = Double.random(in: PetPhysics.pauseDurationMin...PetPhysics.pauseDurationMax)
            pet.roamPauseUntil = now.addingTimeInterval(pauseIn + pauseLen)
        }

        // Check if we reached our roam target
        if let target = pet.target {
            let dx = target.x - pet.position.x
            let dy = target.y - pet.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < 5 {
                pet.velocity = .zero
                pet.target = nil
                // Schedule a pause before picking a new direction
                let pauseLen = Double.random(in: PetPhysics.pauseDurationMin...PetPhysics.pauseDurationMax)
                pet.roamPauseUntil = Date().addingTimeInterval(pauseLen)
                return
            }
        }

        // Turn around at screen edges (X)
        let minX = screenBounds.minX + PetPhysics.edgeMargin
        let maxX = screenBounds.maxX - PetPhysics.edgeMargin
        if pet.position.x <= minX && pet.velocity.x < 0 {
            pet.velocity.x = abs(pet.velocity.x)
            pet.facingRight = true
        } else if pet.position.x >= maxX && pet.velocity.x > 0 {
            pet.velocity.x = -abs(pet.velocity.x)
            pet.facingRight = false
        }

        // Turn around at screen edges (Y)
        let minY = screenBounds.minY + PetPhysics.edgeMargin
        let maxY = screenBounds.maxY - PetPhysics.edgeMargin
        if pet.position.y <= minY && pet.velocity.y < 0 {
            pet.velocity.y = abs(pet.velocity.y)
        } else if pet.position.y >= maxY && pet.velocity.y > 0 {
            pet.velocity.y = -abs(pet.velocity.y)
        }
    }

    // MARK: - Idle Resting (sitting/working — walks to home spot, then rests)

    static func updateIdleResting(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect
    ) {
        // Home spot is where the user last dropped the pet (or spawn position)
        guard let home = pet.lastDropPosition else {
            pet.velocity = .zero
            return
        }

        let dx = home.x - pet.position.x
        let dy = home.y - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < PetPhysics.arrivalThreshold {
            // Arrived at home — rest here
            pet.velocity = .zero
        } else {
            // Walk toward home spot at a leisurely pace
            let vel = velocityToward(
                from: pet.position, to: home,
                speed: PetPhysics.idleWalkSpeed
            )
            pet.velocity = vel
            pet.facingRight = dx > 0
        }
    }

    // MARK: - Attention Seeking (needs attention — run toward mouse cursor)

    static func updateAttentionSeeking(
        _ pet: PetModel, dt: TimeInterval, screenBounds: CGRect
    ) {
        // Always chase the current mouse position
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
        pet.target = mouseTarget

        let dx = mouseTarget.x - pet.position.x
        let dy = mouseTarget.y - pet.position.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist < PetPhysics.attentionArrivalThreshold {
            // Close enough to mouse — stop and alert
            pet.velocity = .zero
        } else {
            // Run toward mouse cursor
            let vel = velocityToward(
                from: pet.position, to: mouseTarget,
                speed: PetPhysics.attentionSpeed
            )
            pet.velocity = vel
            pet.facingRight = dx > 0
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
            pet.bubbleCooldown = Double.random(in: 45...90)
        } else {
            pet.bubbleCooldown = Double.random(in: 30...60)
        }
    }

    private static func bubbleText(for pet: PetModel) -> String? {
        switch pet.state {
        case .sitting:
            // Working state — pet is chilling while agent codes
            return [
                "coding...",
                "thinking...",
                "building...",
                "fixing bugs",
                "almost done",
            ].randomElement()
        case .sleeping:
            return [
                "zzz",
                "...",
            ].randomElement()
        case .alerting:
            return [
                "hey!",
                "need input",
                "waiting...",
            ].randomElement()
        case .barking:
            return [
                "approve?",
                "permission?",
            ].randomElement()
        case .spinning:
            return ["compacting..."].randomElement()
        default:
            return nil
        }
    }

    // MARK: - State Transitions

    static func updateStateTransition(
        _ pet: PetModel, newStatus: SessionStatus
    ) {
        let newState = PetState(from: newStatus)
        guard newState != pet.state else { return }

        let oldState = pet.state
        pet.state = newState
        pet.currentFrame = 0
        pet.frameAccumulator = 0

        // Reset target when changing behavioral mode
        if oldState.isAttentionSeeking != newState.isAttentionSeeking
            || oldState.isMoving != newState.isMoving {
            pet.target = nil
        }

        // Reset roaming when entering a moving state
        if newState.isMoving && !oldState.isMoving {
            pet.roamPauseUntil = nil
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

    // MARK: - Collision Resolution

    static func resolveCollisions(_ pets: [PetModel], minGap: CGFloat) {
        guard pets.count > 1 else { return }
        let sorted = pets.sorted { $0.position.x < $1.position.x }
        for idx in 1..<sorted.count {
            let left = sorted[idx - 1]
            let right = sorted[idx]
            let overlap = (left.position.x + minGap) - right.position.x
            if overlap > 0 {
                // Push each pet apart by half the overlap
                left.position.x -= overlap / 2
                right.position.x += overlap / 2
            }
        }
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
}
