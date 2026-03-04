import AppKit
import Combine
import SwiftUI

/// Top-level coordinator: spawns/despawns pets as sessions appear/disappear,
/// drives the shared animation timer, and manages pet windows.
@MainActor
class PetManager: ObservableObject {
    private let sessionManager: SessionManager
    private var pets: [String: PetModel] = [:]
    private var windows: [String: PetWindow] = [:]
    private var animationTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    @Published var enabled: Bool = false

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        observePreferences()
        observeSessions()
    }

    // MARK: - Preference Observation

    private func observePreferences() {
        // Read initial state
        enabled = UserDefaults.standard.bool(forKey: "desktopPetsEnabled")

        // Watch for changes
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let newValue = UserDefaults.standard.bool(forKey: "desktopPetsEnabled")
                if newValue != self.enabled {
                    self.enabled = newValue
                    if newValue {
                        self.enable()
                    } else {
                        self.disable()
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Enable / Disable

    func enable() {
        enabled = true
        UserDefaults.standard.set(true, forKey: "desktopPetsEnabled")
        syncWithSessions(sessionManager.sessions)
        startAnimationLoop()
    }

    func disable() {
        enabled = false
        UserDefaults.standard.set(false, forKey: "desktopPetsEnabled")
        stopAnimationLoop()
        despawnAll()
    }

    // MARK: - Session Observation

    private func observeSessions() {
        sessionManager.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] sessions in
                guard let self, self.enabled else { return }
                self.syncWithSessions(sessions)
            }
            .store(in: &cancellables)
    }

    /// Diff current pets vs sessions to create/remove as needed.
    func syncWithSessions(_ sessions: [Session]) {
        let activeIds = Set(sessions.map(\.id))
        let petIds = Set(pets.keys)

        // Spawn new pets
        for session in sessions where !petIds.contains(session.id) {
            spawnPet(for: session)
        }

        // Despawn removed sessions
        for petId in petIds where !activeIds.contains(petId) {
            despawnPet(id: petId)
        }

        // Update existing pets' sessions
        for session in sessions {
            if let pet = pets[session.id] {
                pet.session = session
                PetAnimationEngine.updateStateTransition(
                    pet, newStatus: session.status
                )
            }
        }
    }

    // MARK: - Spawn / Despawn

    @discardableResult
    func spawnPet(for session: Session) -> PetModel {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(
            x: 0, y: 0, width: 1440, height: 900
        )
        let kind = PetKind.random()
        let pet = PetModel(session: session, kind: kind, screenBounds: screen)

        let petSize = currentPetSize
        let petView = PetView(
            pet: pet,
            petSize: petSize,
            onDoubleClick: { [weak self] in self?.handleDoubleClick(petId: session.id) },
            onRightClick: { [weak self] point in
                self?.showContextMenu(petId: session.id, at: point)
            }
        )
        let window = PetWindow(petId: session.id, petView: petView)
        window.updateSize(petSize)
        window.syncPosition(position: pet.position, petSize: petSize)
        window.orderFront(nil)

        pets[session.id] = pet
        windows[session.id] = window

        return pet
    }

    func despawnPet(id: String) {
        guard let pet = pets[id] else { return }
        pet.isDisappearing = true
        // The tick loop will set shouldRemove, then we clean up
    }

    private func removePet(id: String) {
        windows[id]?.orderOut(nil)
        windows[id]?.close()
        windows.removeValue(forKey: id)
        pets.removeValue(forKey: id)
    }

    private func despawnAll() {
        for (id, _) in windows {
            windows[id]?.orderOut(nil)
            windows[id]?.close()
        }
        windows.removeAll()
        pets.removeAll()
    }

    // MARK: - Animation Loop

    func startAnimationLoop() {
        guard animationTimer == nil else { return }
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 15.0, repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    private func stopAnimationLoop() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func tick() {
        let dt = 1.0 / 15.0
        let screen = NSScreen.main?.visibleFrame ?? .zero

        // Update each pet
        var toRemove: [String] = []
        for pet in pets.values {
            PetAnimationEngine.tick(pet, dt: dt, screenBounds: screen)
            if pet.shouldRemove {
                toRemove.append(pet.id)
            }
        }

        // Remove finished pets
        for petId in toRemove {
            removePet(id: petId)
        }

        // Resolve collisions
        PetAnimationEngine.resolveCollisions(
            Array(pets.values), minGap: PetPhysics.collisionGap
        )

        // Sync window positions
        let petSize = currentPetSize
        for (id, window) in windows {
            if let pet = pets[id] {
                window.syncPosition(position: pet.position, petSize: petSize)
            }
        }
    }

    // MARK: - Interaction

    private func handleDoubleClick(petId: String) {
        guard let pet = pets[petId] else { return }
        focusTerminal(session: pet.session)
    }

    func showContextMenu(petId: String, at point: NSPoint) {
        guard let pet = pets[petId],
              let window = windows[petId] else { return }

        let menu = NSMenu()

        // Jump to Session
        let jumpItem = NSMenuItem(
            title: "Jump to Session",
            action: #selector(PetMenuTarget.jumpToSession(_:)),
            keyEquivalent: ""
        )
        let target = PetMenuTarget(pet: pet, manager: self)
        jumpItem.target = target
        jumpItem.representedObject = target
        menu.addItem(jumpItem)

        menu.addItem(.separator())

        // Change Animal submenu
        let animalMenu = NSMenu()
        for kind in PetKind.allCases {
            let item = NSMenuItem(
                title: kind.displayName,
                action: #selector(PetMenuTarget.changeAnimal(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = target
            item.tag = PetKind.allCases.firstIndex(of: kind) ?? 0
            item.state = (kind == pet.kind) ? .on : .off
            animalMenu.addItem(item)
        }
        let animalItem = NSMenuItem(title: "Change Animal", action: nil, keyEquivalent: "")
        animalItem.submenu = animalMenu
        menu.addItem(animalItem)

        // Pet Size submenu
        let sizeMenu = NSMenu()
        let currentSize = Int(currentPetSize)
        for (label, size) in [("Small", 48), ("Medium", 64), ("Large", 96)] {
            let item = NSMenuItem(
                title: "\(label) (\(size)pt)",
                action: #selector(PetMenuTarget.changeSize(_:)),
                keyEquivalent: ""
            )
            item.target = target
            item.representedObject = target
            item.tag = size
            item.state = (size == currentSize) ? .on : .off
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Pet Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())

        // Hide This Pet
        let hideItem = NSMenuItem(
            title: "Hide This Pet",
            action: #selector(PetMenuTarget.hidePet(_:)),
            keyEquivalent: ""
        )
        hideItem.target = target
        hideItem.representedObject = target
        menu.addItem(hideItem)

        // Show menu at the pet's window location
        let windowPoint = window.convertPoint(fromScreen: point)
        menu.popUp(
            positioning: nil,
            at: windowPoint,
            in: window.contentView
        )
    }

    func changeAnimal(petId: String, kind: PetKind) {
        guard let pet = pets[petId] else { return }
        pet.kind = kind
        // Recreate window with new view
        let petSize = currentPetSize
        windows[petId]?.orderOut(nil)
        windows[petId]?.close()

        let petView = PetView(
            pet: pet,
            petSize: petSize,
            onDoubleClick: { [weak self] in self?.handleDoubleClick(petId: petId) },
            onRightClick: { [weak self] point in
                self?.showContextMenu(petId: petId, at: point)
            }
        )
        let window = PetWindow(petId: petId, petView: petView)
        window.updateSize(petSize)
        window.syncPosition(position: pet.position, petSize: petSize)
        window.orderFront(nil)
        windows[petId] = window
    }

    func changePetSize(_ size: Int) {
        UserDefaults.standard.set(size, forKey: "desktopPetSize")
        let petSize = CGFloat(size)
        for (_, window) in windows {
            window.updateSize(petSize)
        }
    }

    func hidePet(petId: String) {
        removePet(id: petId)
    }

    var currentPetSize: CGFloat {
        let stored = UserDefaults.standard.integer(forKey: "desktopPetSize")
        return CGFloat(stored > 0 ? stored : 64)
    }
}

// MARK: - Context Menu Target

/// Bridging class to handle NSMenu actions from the context menu.
/// Stored as representedObject on each menu item to keep it alive.
@MainActor
class PetMenuTarget: NSObject {
    let pet: PetModel
    let manager: PetManager

    init(pet: PetModel, manager: PetManager) {
        self.pet = pet
        self.manager = manager
    }

    @objc func jumpToSession(_ sender: NSMenuItem) {
        focusTerminal(session: pet.session)
    }

    @objc func changeAnimal(_ sender: NSMenuItem) {
        let kind = PetKind.allCases[sender.tag]
        manager.changeAnimal(petId: pet.id, kind: kind)
    }

    @objc func changeSize(_ sender: NSMenuItem) {
        manager.changePetSize(sender.tag)
    }

    @objc func hidePet(_ sender: NSMenuItem) {
        manager.hidePet(petId: pet.id)
    }
}
