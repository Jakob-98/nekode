import AppKit
import Combine
import QuartzCore
import SwiftUI

/// Top-level coordinator: spawns/despawns pets as sessions appear/disappear,
/// drives the shared animation timer, and manages pet windows.
@MainActor
class PetManager: ObservableObject {
    private let sessionManager: SessionManager
    private var pets: [String: PetModel] = [:]
    private var windows: [String: PetWindow] = [:]
    private var animationTimer: Timer?
    private var lastTickTime: Double = 0
    private var cancellables: Set<AnyCancellable> = []
    @Published var enabled: Bool = false

    /// Pet IDs that the user chose to hide via context menu.
    /// Persisted so hidden pets don't respawn on session updates.
    private var hiddenPetIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenPetIds), forKey: "hiddenPetIds")
        }
    }

    /// Sources for which desktop pets are disabled (e.g. "copilot", "opencode").
    /// Persisted via UserDefaults. Sessions from disabled sources won't spawn pets.
    private var disabledPetSources: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(disabledPetSources), forKey: "disabledPetSources")
        }
    }

    // MARK: - Vibe Zone

    /// The shared hangout area for all pets. Defaults to lower-right corner.
    /// Persisted via UserDefaults as "vibeZoneX", "vibeZoneY".
    var vibeZone: CGRect {
        get {
            let screen = NSScreen.main?.visibleFrame ?? PetPhysics.fallbackScreen
            let size = vibeZoneSize
            let defaults = UserDefaults.standard
            let hasCustom = defaults.object(forKey: "vibeZoneX") != nil
            if hasCustom {
                let x = CGFloat(defaults.double(forKey: "vibeZoneX"))
                let y = CGFloat(defaults.double(forKey: "vibeZoneY"))
                // Clamp to screen bounds
                let clampedX = max(screen.minX, min(screen.maxX - size.width, x))
                let clampedY = max(screen.minY, min(screen.maxY - size.height, y))
                return CGRect(x: clampedX, y: clampedY, width: size.width, height: size.height)
            }
            // Default: lower-right corner of screen
            return CGRect(
                x: screen.maxX - size.width - 40,
                y: screen.minY + 40,
                width: size.width,
                height: size.height
            )
        }
        set {
            UserDefaults.standard.set(Double(newValue.origin.x), forKey: "vibeZoneX")
            UserDefaults.standard.set(Double(newValue.origin.y), forKey: "vibeZoneY")
        }
    }

    /// Size of the vibe zone — scales with pet count so pets aren't crammed.
    /// Base size fits 1-2 pets comfortably; each additional pet adds space.
    private var vibeZoneSize: CGSize {
        let count = max(1, pets.count)
        let baseW = PetPhysics.vibeZoneBaseWidth
        let baseH = PetPhysics.vibeZoneBaseHeight
        // Each pet beyond 2 adds space so neighbors aren't forced together
        let extra = max(0, count - 2)
        let w = baseW + CGFloat(extra) * PetPhysics.vibeZoneExtraWidth
        let h = baseH + CGFloat(extra) * PetPhysics.vibeZoneExtraHeight
        // Clamp to screen so the zone doesn't exceed available space
        let screen = NSScreen.main?.visibleFrame ?? PetPhysics.fallbackScreen
        return CGSize(
            width: min(w, screen.width - 80),
            height: min(h, screen.height * 0.4)
        )
    }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        // Restore hidden pet IDs from UserDefaults
        let saved = UserDefaults.standard.stringArray(forKey: "hiddenPetIds") ?? []
        self.hiddenPetIds = Set(saved)
        // Restore disabled pet sources from UserDefaults
        let savedSources = UserDefaults.standard.stringArray(forKey: "disabledPetSources") ?? []
        self.disabledPetSources = Set(savedSources)
        observePreferences()
        observeSessions()
        // If pets were enabled before restart, start them up now.
        // observePreferences only reacts to *changes*, so we need
        // to explicitly enable on launch if the pref is already set.
        if enabled {
            enable()
        }
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
                // Check if disabled sources changed
                let newSources = Set(UserDefaults.standard.stringArray(forKey: "disabledPetSources") ?? [])
                if newSources != self.disabledPetSources {
                    self.disabledPetSources = newSources
                    if self.enabled {
                        self.syncWithSessions(self.sessionManager.sessions)
                    }
                }
            }
            .store(in: &cancellables)

        // Watch for vibe zone position changes from Settings
        NotificationCenter.default.publisher(for: .vibeZoneMoved)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self,
                      let positionStr = notification.userInfo?["position"] as? String else { return }
                let position: VibeZonePosition
                switch positionStr {
                case "bottomLeft": position = .bottomLeft
                case "bottomCenter": position = .bottomCenter
                default: position = .bottomRight
                }
                self.moveVibeZone(to: position)
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
        // Filter out sessions from disabled sources
        let allowedSessions = sessions.filter { !disabledPetSources.contains(SessionSource.resolve($0.source).petToggleKey) }

        let activeIds = Set(allowedSessions.map(\.id))
        let petIds = Set(pets.keys)

        // Spawn new pets (skip hidden ones)
        for session in allowedSessions where !petIds.contains(session.id) && !hiddenPetIds.contains(session.id) {
            spawnPet(for: session)
        }

        // Despawn removed sessions (including those now filtered by source)
        for petId in petIds where !activeIds.contains(petId) {
            despawnPet(id: petId)
        }
        // Clean up hidden IDs for sessions that no longer exist
        hiddenPetIds = hiddenPetIds.filter { activeIds.contains($0) }

        // Update existing pets' sessions
        for session in allowedSessions {
            if let pet = pets[session.id] {
                pet.session = session
                PetAnimationEngine.updateStateTransition(
                    pet, newStatus: session.status
                )
            }
        }
    }

    /// Toggle whether pets are shown for a given source key.
    /// Source keys: "claude" (default/nil), "copilot", "opencode", "cli"
    func togglePetsForSource(_ sourceKey: String, enabled: Bool) {
        if enabled {
            disabledPetSources.remove(sourceKey)
        } else {
            disabledPetSources.insert(sourceKey)
        }
        // Re-sync to spawn/despawn pets based on new filter
        if self.enabled {
            syncWithSessions(sessionManager.sessions)
        }
    }

    func petsEnabledForSource(_ sourceKey: String) -> Bool {
        !disabledPetSources.contains(sourceKey)
    }

    // MARK: - Spawn / Despawn

    @discardableResult
    func spawnPet(for session: Session) -> PetModel {
        let screen = NSScreen.main?.visibleFrame ?? PetPhysics.fallbackScreen
        let kind = PetKind.randomUnassigned(excluding: Set(pets.values.map(\.kind)))
        let zone = vibeZone
        let pet = PetModel(session: session, kind: kind, screenBounds: screen, vibeZone: zone)

        let petSize = currentPetSize
        let petView = PetView(
            pet: pet,
            petSize: petSize,
            onClick: { [weak self] in self?.handleClick(petId: session.id) },
            onRightClick: { [weak self] point in
                self?.showContextMenu(petId: session.id, at: point)
            }
        )
        let window = PetWindow(petId: session.id, petView: petView, petSize: petSize)
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
        lastTickTime = CACurrentMediaTime()
        animationTimer = Timer.scheduledTimer(
            withTimeInterval: PetPhysics.tickInterval, repeats: true
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
        let now = CACurrentMediaTime()
        let dt = min(now - lastTickTime, PetPhysics.dtCap)
        lastTickTime = now
        let screen = NSScreen.main?.visibleFrame ?? PetPhysics.fallbackScreen
        let zone = vibeZone

        // Update each pet
        let allPets = Array(pets.values)
        var toRemove: [String] = []
        for pet in allPets {
            PetAnimationEngine.tick(
                pet, dt: dt, screenBounds: screen, allPets: allPets,
                vibeZone: zone
            )
            if pet.shouldRemove {
                toRemove.append(pet.id)
            }
        }

        // Remove finished pets
        for petId in toRemove {
            removePet(id: petId)
        }

        // Resolve collisions (2D personal space)
        PetAnimationEngine.resolveCollisions(
            Array(pets.values), minGap: PetPhysics.personalSpace
        )

        // Sync window positions and z-order (lower Y = in front)
        let petSize = currentPetSize
        let sortedByDepth = pets.values.sorted { $0.position.y > $1.position.y }
        for (zIndex, pet) in sortedByDepth.enumerated() {
            if let window = windows[pet.id] {
                window.syncPosition(position: pet.position, petSize: petSize)
                // orderedIndex 0 = furthest back, increasing = closer to viewer
                window.depthOrder = zIndex
            }
        }
    }

    // MARK: - Interaction

    private func handleClick(petId: String) {
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

        // Change Color submenu
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
        let animalItem = NSMenuItem(title: "Change Color", action: nil, keyEquivalent: "")
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
        let sizeItem = NSMenuItem(title: "Cat Size", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        menu.addItem(.separator())

        // Hide This Pet
        let hideItem = NSMenuItem(
            title: "Hide This Cat",
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
            onClick: { [weak self] in self?.handleClick(petId: petId) },
            onRightClick: { [weak self] point in
                self?.showContextMenu(petId: petId, at: point)
            }
        )
        let window = PetWindow(petId: petId, petView: petView, petSize: petSize)
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
        hiddenPetIds.insert(petId)
        removePet(id: petId)
    }

    func returnPetToVibeZone(petId: String) {
        guard let pet = pets[petId] else { return }
        let zone = vibeZone
        let targetX = CGFloat.random(in: zone.minX + 20...zone.maxX - 20)
        let targetY = CGFloat.random(in: zone.minY + 20...zone.maxY - 20)
        pet.lastDropPosition = CGPoint(x: targetX, y: targetY)
        pet.hasCustomHome = false
        pet.isReturningToZone = true
        wakeSleepingPet(pet)
    }

    /// Return all pets to the vibe zone, clearing any custom home positions.
    func returnAllPetsToVibeZone() {
        let zone = vibeZone
        for pet in pets.values {
            let targetX = CGFloat.random(in: zone.minX + 20...zone.maxX - 20)
            let targetY = CGFloat.random(in: zone.minY + 20...zone.maxY - 20)
            pet.lastDropPosition = CGPoint(x: targetX, y: targetY)
            pet.hasCustomHome = false
            pet.isReturningToZone = true
            wakeSleepingPet(pet)
        }
    }

    /// Wake a sleeping pet so it can run to its target instead of sleep-crawling.
    private func wakeSleepingPet(_ pet: PetModel) {
        guard pet.state == .sleeping else { return }
        pet.state = .sitting
        pet.sleepDrifting = false
        pet.sleepDriftTarget = nil
        pet.sleepWakeTimeRemaining = 0
        pet.sleepBlinking = false
        pet.currentFrame = 0
        pet.frameAccumulator = 0
        pet.idleTime = 0
    }

    func moveVibeZone(to position: VibeZonePosition) {
        let screen = NSScreen.main?.visibleFrame ?? PetPhysics.fallbackScreen
        let size = vibeZoneSize
        let newOrigin: CGPoint
        switch position {
        case .bottomLeft:
            newOrigin = CGPoint(x: screen.minX + 40, y: screen.minY + 40)
        case .bottomRight:
            newOrigin = CGPoint(x: screen.maxX - size.width - 40, y: screen.minY + 40)
        case .bottomCenter:
            newOrigin = CGPoint(x: screen.midX - size.width / 2, y: screen.minY + 40)
        }
        vibeZone = CGRect(origin: newOrigin, size: size)

        // Move all non-custom-home pets to the new zone
        for pet in pets.values where !pet.hasCustomHome {
            let zone = vibeZone
            let targetX = CGFloat.random(in: zone.minX + 20...zone.maxX - 20)
            let targetY = CGFloat.random(in: zone.minY + 20...zone.maxY - 20)
            pet.lastDropPosition = CGPoint(x: targetX, y: targetY)
        }
    }

    enum VibeZonePosition {
        case bottomLeft, bottomRight, bottomCenter
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
