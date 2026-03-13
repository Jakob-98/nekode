import XCTest
@testable import Nekode

// MARK: - PetState Smoke Tests

final class PetStateTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PetState.allCases.count, 19)
    }

    func testSpriteRowNonNegativeForAllCases() {
        for state in PetState.allCases {
            XCTAssertGreaterThanOrEqual(state.spriteRow, 0)
        }
    }

    func testFrameCountPositiveForAllCases() {
        for state in PetState.allCases {
            XCTAssertGreaterThan(state.frameCount, 0)
        }
    }

    func testAllSessionStatusesMapped() {
        let allStatuses: [SessionStatus] = [
            .idle, .working, .compacting,
            .waitingInput, .needsAttention, .waitingPermission,
        ]
        for status in allStatuses {
            _ = PetState(from: status) // Should not crash
        }
    }

    func testWorkingMapsToSitting() {
        XCTAssertEqual(PetState(from: .working), .sitting)
    }

    func testIdleMapsToSleeping() {
        XCTAssertEqual(PetState(from: .idle), .sleeping)
    }

    func testAttentionStatesAreMoving() {
        XCTAssertTrue(PetState.alerting.isMoving)
        XCTAssertTrue(PetState.barking.isMoving)
    }

    func testAttentionStatesAreAttentionSeeking() {
        XCTAssertTrue(PetState.alerting.isAttentionSeeking)
        XCTAssertTrue(PetState.barking.isAttentionSeeking)
    }
}

// MARK: - PetKind Smoke Tests

final class PetKindTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PetKind.allCases.count, 6)
    }

    func testCellSizeIs64x64() {
        for kind in PetKind.allCases {
            XCTAssertEqual(kind.cellSize.width, 64)
            XCTAssertEqual(kind.cellSize.height, 64)
        }
    }

    func testCodableRoundtrip() throws {
        for kind in PetKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(PetKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testRandomUnassignedReturnsValidKind() {
        for _ in 0..<20 {
            XCTAssertTrue(PetKind.allCases.contains(PetKind.randomUnassigned(excluding: [])))
        }
    }
}

// MARK: - PetModel Smoke Tests

@MainActor
final class PetModelTests: XCTestCase {
    private let screenBounds = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testInitSetsIdFromSession() {
        let session = Session.mock(status: .idle, pid: 12345)
        let pet = PetModel(session: session, kind: .pochi, screenBounds: screenBounds)
        XCTAssertEqual(pet.id, "12345")
    }

    func testInitStartsWithAppearAnimation() {
        let pet = makePet()
        XCTAssertTrue(pet.isAppearing)
        XCTAssertEqual(pet.opacity, 0)
        XCTAssertEqual(pet.scale, 0.5)
    }

    func testInitSpawnsWithinBounds() {
        for _ in 0..<50 {
            let pet = makePet()
            XCTAssertGreaterThanOrEqual(pet.position.x, screenBounds.minX + 40)
            XCTAssertLessThanOrEqual(pet.position.x, screenBounds.maxX - 40)
            XCTAssertGreaterThanOrEqual(pet.position.y, screenBounds.minY + 40)
            XCTAssertLessThanOrEqual(pet.position.y, screenBounds.maxY - 40)
        }
    }

    func testVelocityIsCGPoint() {
        let pet = makePet()
        XCTAssertEqual(pet.velocity, .zero)
    }

    func testTargetIsCGPointOptional() {
        let pet = makePet()
        XCTAssertNil(pet.target)
        pet.target = CGPoint(x: 100, y: 200)
        XCTAssertEqual(pet.target, CGPoint(x: 100, y: 200))
    }

    func testSpeechBubbleForAttentionStates() {
        let barkingPet = makePet(status: .waitingPermission)
        XCTAssertEqual(barkingPet.speechBubble, "!")

        let alertingPet = makePet(status: .waitingInput)
        XCTAssertEqual(alertingPet.speechBubble, "?")
    }

    func testSpeechBubbleNilForNonAttentionStates() {
        for status: SessionStatus in [.idle, .working, .compacting] {
            let pet = makePet(status: status)
            XCTAssertNil(pet.speechBubble)
        }
    }

    private func makePet(status: SessionStatus = .idle) -> PetModel {
        PetModel(
            session: .mock(status: status, pid: 999),
            kind: .pochi,
            screenBounds: screenBounds
        )
    }
}

// MARK: - PetAnimationEngine Smoke Tests

@MainActor
final class PetAnimationEngineTests: XCTestCase {
    private let screenBounds = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testAppearCompletesAfterDuration() {
        let pet = makePet()
        PetAnimationEngine.tick(
            pet, dt: PetPhysics.appearDuration,
            screenBounds: screenBounds
        )
        XCTAssertFalse(pet.isAppearing)
        XCTAssertEqual(pet.opacity, 1.0)
        XCTAssertEqual(pet.scale, 1.0)
    }

    func testDisappearSetsShouldRemove() {
        let pet = makePet()
        finishAppearing(pet)
        pet.isDisappearing = true
        pet.opacity = 1.0
        PetAnimationEngine.tick(
            pet, dt: PetPhysics.disappearDuration,
            screenBounds: screenBounds
        )
        XCTAssertTrue(pet.shouldRemove)
    }

    func testDraggingPreventsMovement() {
        let pet = makePet()
        finishAppearing(pet)
        pet.state = .walking
        pet.velocity = CGPoint(x: PetPhysics.roamSpeed, y: 0)
        pet.isDragging = true
        let initialPos = pet.position
        PetAnimationEngine.tick(pet, dt: 1.0, screenBounds: screenBounds)
        XCTAssertEqual(pet.position.x, initialPos.x)
        XCTAssertEqual(pet.position.y, initialPos.y)
    }

    func testTickWithZeroDtDoesNotCrash() {
        let pet = makePet()
        finishAppearing(pet)
        pet.state = .walking
        PetAnimationEngine.tick(pet, dt: 0, screenBounds: screenBounds)
        XCTAssertFalse(pet.position.x.isNaN)
        XCTAssertFalse(pet.position.y.isNaN)
    }

    func testClampToScreenBothAxes() {
        let pet = makePet()
        pet.position = CGPoint(x: -100, y: -100)
        PetAnimationEngine.clampToScreen(pet, screenBounds: screenBounds)
        XCTAssertEqual(pet.position.x, screenBounds.minX + PetPhysics.edgeMargin)
        XCTAssertEqual(pet.position.y, screenBounds.minY + PetPhysics.edgeMargin)

        pet.position = CGPoint(x: 2000, y: 2000)
        PetAnimationEngine.clampToScreen(pet, screenBounds: screenBounds)
        XCTAssertEqual(pet.position.x, screenBounds.maxX - PetPhysics.edgeMargin)
        XCTAssertEqual(pet.position.y, screenBounds.maxY - PetPhysics.edgeMargin)
    }

    func testStateTransitionResetsFrame() {
        let pet = makePet()
        finishAppearing(pet)
        pet.state = .sitting
        pet.currentFrame = 3
        pet.frameAccumulator = 0.5
        PetAnimationEngine.updateStateTransition(pet, newStatus: .idle)
        XCTAssertEqual(pet.state, .sleeping)
        XCTAssertEqual(pet.currentFrame, 0)
        XCTAssertEqual(pet.frameAccumulator, 0)
    }

    func testResolveCollisionsNoCrash() {
        PetAnimationEngine.resolveCollisions([], minGap: 60)
        PetAnimationEngine.resolveCollisions([makePet()], minGap: 60)
    }

    func testResolveCollisions2DPushesApart() {
        let pet1 = makePet()
        let pet2 = makePet()
        finishAppearing(pet1)
        finishAppearing(pet2)
        // Place pets ~22pt apart (less than 60pt personal space)
        pet1.position = CGPoint(x: 500, y: 500)
        pet2.position = CGPoint(x: 520, y: 510)
        let dxBefore = pet2.position.x - pet1.position.x
        let dyBefore = pet2.position.y - pet1.position.y
        let distBefore = sqrt(dxBefore * dxBefore + dyBefore * dyBefore)

        // Single call applies gentle 30% correction — pets should move apart
        PetAnimationEngine.resolveCollisions([pet1, pet2], minGap: 60)
        let dx1 = pet2.position.x - pet1.position.x
        let dy1 = pet2.position.y - pet1.position.y
        let distAfterOne = sqrt(dx1 * dx1 + dy1 * dy1)
        XCTAssertGreaterThan(distAfterOne, distBefore,
                             "Single iteration should push pets further apart")

        // After repeated iterations the correction converges to minGap
        for _ in 0..<20 {
            PetAnimationEngine.resolveCollisions([pet1, pet2], minGap: 60)
        }
        let dx2 = pet2.position.x - pet1.position.x
        let dy2 = pet2.position.y - pet1.position.y
        let distFinal = sqrt(dx2 * dx2 + dy2 * dy2)
        XCTAssertGreaterThanOrEqual(distFinal, 59.9,
                                    "After convergence pets should be at least minGap apart")
    }

    func testResolveCollisionsSkipsDragging() {
        let pet1 = makePet()
        let pet2 = makePet()
        finishAppearing(pet1)
        finishAppearing(pet2)
        pet1.position = CGPoint(x: 500, y: 500)
        pet2.position = CGPoint(x: 510, y: 500)
        pet2.isDragging = true
        let originalPos2 = pet2.position
        PetAnimationEngine.resolveCollisions([pet1, pet2], minGap: 60)
        // Dragging pet should not be moved
        XCTAssertEqual(pet2.position.x, originalPos2.x)
        XCTAssertEqual(pet2.position.y, originalPos2.y)
    }

    func testResolveCollisionsNoEffectWhenFarApart() {
        let pet1 = makePet()
        let pet2 = makePet()
        finishAppearing(pet1)
        finishAppearing(pet2)
        pet1.position = CGPoint(x: 100, y: 500)
        pet2.position = CGPoint(x: 500, y: 500)
        let orig1 = pet1.position
        let orig2 = pet2.position
        PetAnimationEngine.resolveCollisions([pet1, pet2], minGap: 60)
        XCTAssertEqual(pet1.position.x, orig1.x)
        XCTAssertEqual(pet2.position.x, orig2.x)
    }

    func testAttentionTargetSinglePetReturnsMouse() {
        let pet = makePet()
        let mouse = CGPoint(x: 700, y: 450)
        let target = PetAnimationEngine.attentionTarget(
            for: pet, allPets: [pet], mouseTarget: mouse
        )
        XCTAssertEqual(target.x, mouse.x)
        XCTAssertEqual(target.y, mouse.y)
    }

    func testAttentionTargetMultiplePetsSpread() {
        let pet1 = makePet()
        // Give distinct IDs
        let session2 = Session.mock(status: .waitingInput, pid: 998)
        let petB = PetModel(
            session: session2, kind: .pochiBlack, screenBounds: screenBounds
        )
        pet1.state = .alerting
        pet1.attentionTime = 15  // Stage 2
        petB.state = .alerting
        petB.attentionTime = 15
        finishAppearing(pet1)
        finishAppearing(petB)
        let mouse = CGPoint(x: 700, y: 450)
        let t1 = PetAnimationEngine.attentionTarget(
            for: pet1, allPets: [pet1, petB], mouseTarget: mouse
        )
        let t2 = PetAnimationEngine.attentionTarget(
            for: petB, allPets: [pet1, petB], mouseTarget: mouse
        )
        // Targets should be different
        let dist = sqrt(
            pow(t1.x - t2.x, 2) + pow(t1.y - t2.y, 2)
        )
        XCTAssertGreaterThan(dist, 10)
    }

    func testStepAnimationAdvancesFrame() {
        let pet = makePet()
        finishAppearing(pet)
        pet.state = .walking
        pet.currentFrame = 0
        pet.frameAccumulator = 0
        PetAnimationEngine.stepAnimation(pet, dt: 0.2)
        XCTAssertGreaterThan(pet.currentFrame, 0)
    }

    // MARK: - Helpers

    private func makePet() -> PetModel {
        PetModel(
            session: .mock(status: .idle, pid: 999),
            kind: .pochi,
            screenBounds: screenBounds
        )
    }

    private func finishAppearing(_ pet: PetModel) {
        pet.isAppearing = false
        pet.opacity = 1.0
        pet.scale = 1.0
    }
}

// MARK: - SpriteGridConfig Smoke Tests

final class SpriteGridConfigTests: XCTestCase {

    func testAllRowsHavePositiveFrames() {
        for (key, config) in PochiSpriteGrid.allRows {
            XCTAssertGreaterThan(config.frames, 0, "Row '\(key)' has 0 frames")
        }
    }

    func testAllRowsHaveUniqueRows() {
        // Not all are unique (some states share rows), but each key should resolve
        for (key, _) in PochiSpriteGrid.allRows {
            XCTAssertNotNil(PochiSpriteGrid.config(for: key), "Missing config for '\(key)'")
        }
    }

    func testSleepingHas4Frames() {
        let config = PochiSpriteGrid.config(for: "sleeping")
        XCTAssertNotNil(config)
        XCTAssertEqual(config!.frames, 4)
    }

    func testAlertingSkipsColumn6() {
        let config = PochiSpriteGrid.config(for: "alerting")
        XCTAssertNotNil(config)
        XCTAssertTrue(config!.skipColumns.contains(6))
        XCTAssertEqual(config!.frames, 7)
    }

    func testBoxIdleDoesNotLoop() {
        let config = PochiSpriteGrid.config(for: "boxIdle")
        XCTAssertNotNil(config)
        XCTAssertFalse(config!.loops)
    }

    func testAllPetStatesHaveValidGridKey() {
        for state in PetState.allCases {
            XCTAssertNotNil(
                PochiSpriteGrid.config(for: state.gridKey),
                "PetState.\(state) has invalid gridKey '\(state.gridKey)'"
            )
        }
    }
}

// MARK: - PetPhysics Smoke Tests

final class PetPhysicsTests: XCTestCase {

    func testConstantsArePositive() {
        XCTAssertGreaterThan(PetPhysics.roamSpeed, 0)
        XCTAssertGreaterThan(PetPhysics.attentionSpeed, 0)
        XCTAssertGreaterThan(PetPhysics.edgeMargin, 0)
        XCTAssertGreaterThan(PetPhysics.personalSpace, 0)
        XCTAssertGreaterThan(PetPhysics.appearDuration, 0)
        XCTAssertGreaterThan(PetPhysics.disappearDuration, 0)
    }

    func testPersonalSpaceGreaterThanZero() {
        XCTAssertGreaterThanOrEqual(PetPhysics.personalSpace, 40)
    }

    func testAttentionSpeedGreaterThanRoamSpeed() {
        XCTAssertGreaterThan(PetPhysics.attentionSpeed, PetPhysics.roamSpeed)
    }
}
