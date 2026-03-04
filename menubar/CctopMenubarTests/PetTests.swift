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
        PetAnimationEngine.resolveCollisions([], minGap: 20)
        PetAnimationEngine.resolveCollisions([makePet()], minGap: 20)
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
        XCTAssertGreaterThan(PetPhysics.appearDuration, 0)
        XCTAssertGreaterThan(PetPhysics.disappearDuration, 0)
    }

    func testAttentionSpeedGreaterThanRoamSpeed() {
        XCTAssertGreaterThan(PetPhysics.attentionSpeed, PetPhysics.roamSpeed)
    }
}
