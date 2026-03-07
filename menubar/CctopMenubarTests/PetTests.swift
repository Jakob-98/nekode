import XCTest
@testable import CctopMenubar

// MARK: - PetState Smoke Tests

final class PetStateTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(PetState.allCases.count, 9)
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
        XCTAssertEqual(PetKind.allCases.count, 3)
    }

    func testCellSizeIs24x24() {
        for kind in PetKind.allCases {
            XCTAssertEqual(kind.cellSize.width, 24)
            XCTAssertEqual(kind.cellSize.height, 24)
        }
    }

    func testCodableRoundtrip() throws {
        for kind in PetKind.allCases {
            let data = try JSONEncoder().encode(kind)
            let decoded = try JSONDecoder().decode(PetKind.self, from: data)
            XCTAssertEqual(decoded, kind)
        }
    }

    func testRandomReturnsValidKind() {
        for _ in 0..<20 {
            XCTAssertTrue(PetKind.allCases.contains(PetKind.random()))
        }
    }
}

// MARK: - PetModel Smoke Tests

@MainActor
final class PetModelTests: XCTestCase {
    private let screenBounds = CGRect(x: 0, y: 0, width: 1440, height: 900)

    func testInitSetsIdFromSession() {
        let session = Session.mock(status: .idle, pid: 12345)
        let pet = PetModel(session: session, kind: .dog, screenBounds: screenBounds)
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
            kind: .dog,
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
        // Place pets 30px apart (less than 60px personal space)
        pet1.position = CGPoint(x: 500, y: 500)
        pet2.position = CGPoint(x: 520, y: 510)
        PetAnimationEngine.resolveCollisions([pet1, pet2], minGap: 60)
        let dx = pet2.position.x - pet1.position.x
        let dy = pet2.position.y - pet1.position.y
        let dist = sqrt(dx * dx + dy * dy)
        // After resolution, they should be at least minGap apart
        XCTAssertGreaterThanOrEqual(dist, 59.9)
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
        let pet2 = makePet()
        // Give distinct IDs
        let session2 = Session.mock(status: .waitingInput, pid: 998)
        let petB = PetModel(
            session: session2, kind: .cat, screenBounds: screenBounds
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

    func testGatheringTargetNilForSinglePet() {
        let pet = makePet()
        let result = PetAnimationEngine.gatheringTarget(
            for: pet, allPets: [pet]
        )
        XCTAssertNil(result)
    }

    func testGatheringTargetReturnsCentroidWhenFar() {
        let pet1 = makePet()
        // Distinct ID so gatheringTarget's id filter doesn't exclude pet2
        let pet2 = PetModel(
            session: .mock(id: "other-pet", status: .idle, pid: 998),
            kind: .cat, screenBounds: screenBounds
        )
        finishAppearing(pet1)
        finishAppearing(pet2)
        // pet1 is roaming far away, pet2 is sitting still
        pet1.state = .walking
        pet1.position = CGPoint(x: 100, y: 100)
        pet2.state = .sitting
        pet2.velocity = .zero
        pet2.position = CGPoint(x: 700, y: 500)
        let result = PetAnimationEngine.gatheringTarget(
            for: pet1, allPets: [pet1, pet2]
        )
        XCTAssertNotNil(result)
        // Should be near pet2's position (the centroid of sitters)
        XCTAssertEqual(result!.x, 700, accuracy: 1)
        XCTAssertEqual(result!.y, 500, accuracy: 1)
    }

    func testGatheringTargetNilWhenClose() {
        let pet1 = makePet()
        // Distinct ID so the filter actually includes pet2
        let pet2 = PetModel(
            session: .mock(id: "other-pet", status: .idle, pid: 998),
            kind: .cat, screenBounds: screenBounds
        )
        finishAppearing(pet1)
        finishAppearing(pet2)
        pet1.state = .walking
        pet1.position = CGPoint(x: 500, y: 500)
        pet2.state = .sitting
        pet2.velocity = .zero
        pet2.position = CGPoint(x: 550, y: 500)
        // 50px apart — within gatheringRadius (120px)
        let result = PetAnimationEngine.gatheringTarget(
            for: pet1, allPets: [pet1, pet2]
        )
        XCTAssertNil(result)
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
            kind: .dog,
            screenBounds: screenBounds
        )
    }

    private func finishAppearing(_ pet: PetModel) {
        pet.isAppearing = false
        pet.opacity = 1.0
        pet.scale = 1.0
    }
}

// MARK: - PetPhysics Smoke Tests

final class PetPhysicsTests: XCTestCase {

    func testConstantsArePositive() {
        XCTAssertGreaterThan(PetPhysics.roamSpeed, 0)
        XCTAssertGreaterThan(PetPhysics.attentionSpeed, 0)
        XCTAssertGreaterThan(PetPhysics.edgeMargin, 0)
        XCTAssertGreaterThan(PetPhysics.personalSpace, 0)
        XCTAssertGreaterThan(PetPhysics.gatheringRadius, 0)
        XCTAssertGreaterThan(PetPhysics.appearDuration, 0)
        XCTAssertGreaterThan(PetPhysics.disappearDuration, 0)
    }

    func testPersonalSpaceGreaterThanZero() {
        XCTAssertGreaterThanOrEqual(PetPhysics.personalSpace, 40)
    }

    func testGatheringRadiusGreaterThanPersonalSpace() {
        XCTAssertGreaterThan(
            PetPhysics.gatheringRadius, PetPhysics.personalSpace
        )
    }

    func testAttentionSpeedGreaterThanRoamSpeed() {
        XCTAssertGreaterThan(PetPhysics.attentionSpeed, PetPhysics.roamSpeed)
    }
}
