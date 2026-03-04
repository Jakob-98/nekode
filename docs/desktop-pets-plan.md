# Desktop Pet Agents — Design & Implementation Plan

## 1. General Idea

cctop already shows AI coding session status in a menubar popup and via Raycast.
Desktop Pets adds a **playful, ambient layer**: small pixel-art animals (dogs, cats,
hamsters) that live directly on the macOS desktop, one per active session. Each pet
is a transparent, always-on-top, draggable window that **visually reflects the state
of its session** and lets you interact with it.

The core insight is that each pet *is* an agent proxy. When your Claude Code session
needs permission, the dog barks and **runs toward your mouse cursor**. Double-click
it to jump straight into that terminal. When the session is working, the pet sits
and chills (it's busy coding!). When idle, the hamster sleeps. You never need to
open the menubar popup for the common case — the pets bring the status to you.

### Goals

- **Ambient awareness** — Glanceable session status without any UI chrome.
- **Direct interaction** — Click a pet to jump to its session immediately.
- **Delight** — Pixel-art animals with personality make the dev experience more fun.
- **Non-intrusive** — Disabled by default. When enabled, pets are small, draggable,
  and dismissable. They never block content or steal focus.

### Non-Goals

- Replacing the menubar popup or Raycast extension. Pets are a supplemental layer.
- Sound effects (at least for v1).
- Full virtual pet simulation (hunger, mood, leveling up, etc.).

---

## 2. Features

### 2.1 Pet Lifecycle

- When a new session appears in `SessionManager`, a pet is spawned on-screen.
- When a session dies (PID check fails), its pet plays a short "goodbye" animation
  and disappears.
- Pets are **randomly assigned** an animal kind (dog, cat, or hamster) at spawn time.
  The user can change the animal via right-click context menu.
- Assignment is **not persisted** — each new session gets a fresh random pet. (This
  keeps it simple and surprising.)

### 2.2 Status-Driven Animation

Each pet has a set of sprite animations mapped to session status:

| Session Status       | Pet Animation                        | Movement Behavior                   |
|----------------------|--------------------------------------|-------------------------------------|
| `idle`               | Sleeping (slow breathing, eyes shut) | Stays in place                      |
| `working`            | Sitting / idle (chilling)            | Gently drifts toward mouse, rests   |
| `compacting`         | Chasing tail / hamster wheel spin    | Spins in place                      |
| `waitingInput`       | Alert anim, run, bubble "?"          | **Runs toward mouse cursor (2D)**   |
| `waitingPermission`  | Alert anim, run, bubble "!"          | **Runs toward mouse cursor (2D)**   |
| `needsAttention`     | Same as `waitingInput`               | **Runs toward mouse cursor (2D)**   |

Transitions between states are animated — e.g., a running pet slows down and lies
down when the session goes idle, rather than snapping instantly.

### 2.3 Movement & Roaming

- **Free 2D roaming**: Pets move freely across the full screen in both X and Y axes.
  There is no gravity or bottom-edge pinning. Pets pick random 2D targets within
  screen bounds, walk toward them at ~70 pt/s, pause for 1–3 seconds, then pick a
  new target. Pauses happen every 2–8 seconds.
- **Idle resting (working state)**: When the session is `working`, the pet is in
  `sitting` state and gently drifts toward the mouse cursor at a leisurely pace
  (~50 pt/s), then rests nearby. It re-checks the mouse position every ~8 seconds
  and only moves if the mouse has moved significantly.
- **Attention-seeking**: When the session needs interaction (`waitingInput`,
  `waitingPermission`, `needsAttention`), the pet **runs toward the current mouse
  cursor position** at ~100 pt/s in both X and Y. It continuously tracks the cursor
  and stops within ~40pt of it, playing its alert animation until the status changes.
- **Screen edges**: Pets clamp to screen bounds (both axes, with a 20pt edge margin).
  When reaching an edge while roaming, they reverse direction on that axis.
- **Direction**: The sprite is flipped horizontally (`scaleEffect(x: -1)`) when
  moving left (based on the X component of velocity).

### 2.4 Interaction

| Gesture                  | Context                | Action                                            |
|--------------------------|------------------------|---------------------------------------------------|
| **Double-click**         | Any                    | Jump to session terminal (`FocusTerminal`)         |
| **Right-click**          | Any                    | Context menu (see below)                           |
| **Drag**                 | Any                    | Reposition pet; it stays where dropped permanently |
| **Hover**                | Any                    | Small floating name tag with project name          |

**Right-click context menu:**

```
Jump to Session
─────────────────
Change Animal  >  Dog
                  Cat
                  Hamster
─────────────────
Pet Size       >  Small (48pt)
                  Medium (64pt)  ✓
                  Large (96pt)
─────────────────
Hide This Pet
```

### 2.5 Visual Elements

- **Sprite**: The main pet graphic, animated frame-by-frame from a sprite sheet.
- **Name tag**: A small label below the pet showing the project name (e.g., "cctop").
  Appears on hover or always-on (user preference TBD).
- **Speech bubble**: A dark rounded rect with white text ("!" or "?" for attention
  states, or contextual phrases like "coding...", "zzz") above the pet's head. Bobs
  gently up and down. Driven by a cooldown-based engine that shows random contextual
  bubbles every 12–25 seconds.
- **Source badge**: Tiny "CC" or "OC" indicator in the corner, matching the menubar
  popup's source badge style. Only shown when sessions come from multiple sources.

### 2.6 Settings

Added to the existing Settings panel in the menubar popup:

- **Desktop Pets** — Toggle (default: OFF)
- **Pet Size** — Small (48pt) / Medium (64pt, default) / Large (96pt)

Stored via `@AppStorage`:

```swift
@AppStorage("desktopPetsEnabled") var desktopPetsEnabled = false
@AppStorage("desktopPetSize") var desktopPetSize = 64  // points
```

### 2.7 Multi-Pet Behavior

When multiple sessions are active, multiple pets coexist:

- **Collision avoidance**: Pets maintain a minimum distance (~20pt gap). If two pets
  overlap, the one that arrived later nudges aside.
- **Stacking**: When attention-seeking, multiple pets queue near screen center rather
  than piling on the same spot.
- **Identity**: Each pet's name tag and tooltip make it clear which session it
  represents.

---

## 3. Art & Sprites

### 3.1 Style

Pixel art, ~32x32 pixels per frame, rendered at 2x for retina (displaying at
64x64pt at medium size). Classic desktop-pet aesthetic reminiscent of Neko, Shimeji,
or Tamagotchi. Fits the developer-tool vibe — charming without being distracting.

### 3.2 Sprite Sheet Format

Each animal has one PNG sprite sheet organized as a grid:

```
Columns: animation frames (left to right)
Rows:    animation states (top to bottom)
```

Example layout for `dog-sprites.png` (32x32 per frame, 8 columns x 6 rows):

| Row | State          | Frames | Description                          |
|-----|----------------|--------|--------------------------------------|
| 0   | Idle / Sit     | 2–3    | Breathing, blinking                  |
| 1   | Walk           | 4–6    | Trotting right                       |
| 2   | Run            | 4–6    | Faster trot (for working status)     |
| 3   | Sleep          | 2      | Lying down, breathing slowly         |
| 4   | Alert          | 3–4    | Sitting up, barking (for attention)  |
| 5   | Special        | 4–6    | Tail chasing (for compacting)        |

All sprites face **right** by default. Left-facing is achieved by mirroring at
render time.

### 3.3 Asset Catalog

```
Assets.xcassets/
  Pets/
    dog-sprites.imageset/
      dog-sprites.png        (1x — 256x192)
      dog-sprites@2x.png     (2x — 512x384)
    cat-sprites.imageset/
      cat-sprites.png
      cat-sprites@2x.png
    hamster-sprites.imageset/
      hamster-sprites.png
      hamster-sprites@2x.png
```

### 3.4 Placeholder Strategy

For initial development, use **programmatic placeholders**: simple colored rounded
rectangles with SF Symbol overlays (e.g., a green rectangle with `hare.fill` for
running). This lets the entire system be built and tested without waiting on art.
Real sprites are swapped in as a final step.

---

## 4. Implementation Details

### 4.1 File Structure

All new code lives in `menubar/CctopMenubar/Pets/`. No new Xcode targets.

```
menubar/CctopMenubar/
  Pets/
    PetKind.swift               # Animal enum + sprite sheet metadata
    PetState.swift              # Animation state enum, mapped from SessionStatus
    PetModel.swift              # Per-pet state: position, velocity, animation, session binding
    PetSpriteSheet.swift        # Loads PNG atlas, extracts frames by row/column
    PetAnimationEngine.swift    # Movement physics, roaming AI, attention-seeking, frame stepping
    PetWindow.swift             # NSPanel subclass (transparent, floating, draggable)
    PetView.swift               # SwiftUI view (sprite + name tag + speech bubble)
    PetManager.swift            # Lifecycle manager: session binding, shared timer, create/destroy
    PetInteraction.swift        # Click, right-click, drag handlers
```

### 4.2 PetKind (`PetKind.swift`)

```swift
enum PetKind: String, CaseIterable, Codable {
    case dog, cat, hamster

    var spriteSheetName: String  // Asset catalog name
    var frameSize: CGSize        // Size of one frame in the sheet (e.g., 32x32)
    var framesPerRow: Int        // Number of columns in the sprite sheet
    var animationFPS: Double     // Frames per second for this animal (8–12)
}
```

Includes a `static func random() -> PetKind` for spawn-time assignment.

### 4.3 PetState (`PetState.swift`)

```swift
enum PetState: Int {
    case sleeping       // idle
    case sitting        // idle (brief, before sleep)
    case walking        // working (roaming)
    case running        // working (fast variant, unused in v1)
    case alerting       // waitingInput, needsAttention
    case barking        // waitingPermission
    case spinning       // compacting
    case appearing      // spawn animation
    case disappearing   // despawn animation

    var spriteRow: Int          // Which row in the sprite sheet
    var frameCount: Int         // How many frames in this animation
    var loops: Bool             // Whether the animation loops (most do)

    init(from status: SessionStatus)  // Maps session status → pet state
}
```

### 4.4 PetModel (`PetModel.swift`)

```swift
@MainActor
class PetModel: ObservableObject, Identifiable {
    let id: String                      // Matches session PID-based ID
    var kind: PetKind
    var session: Session                // Updated by PetManager on each tick

    // Spatial
    @Published var position: CGPoint    // Screen coordinates (bottom-left origin)
    @Published var velocity: CGPoint = .zero  // 2D speed vector
    @Published var facingRight: Bool

    // Animation
    @Published var state: PetState
    @Published var currentFrame: Int    // Current sprite frame index
    var frameAccumulator: Double        // Fractional frame counter for FPS control

    // Behavior
    @Published var isDragging: Bool
    var target: CGPoint?                // Where to move toward (nil = roaming)
    var roamPauseUntil: Date?           // Random pause during roaming
    var lastTargetUpdate: Date?         // When idle target was last updated

    // Speech Bubbles
    @Published var activeBubbleText: String?
    var bubbleTimeRemaining: Double     // How long current bubble stays
    var bubbleCooldown: Double          // Seconds until next bubble check

    // Lifecycle
    @Published var opacity: Double
    @Published var scale: Double
    var isAppearing: Bool
    var isDisappearing: Bool
    var shouldRemove: Bool

    // Computed
    var displayName: String { session.displayName }
    var needsAttention: Bool { session.status.needsAttention }
    var speechBubble: String? {
        if let active = activeBubbleText { return active }
        switch state {
        case .barking: return "!"
        case .alerting: return "?"
        default: return nil
        }
    }

    init(session: Session, kind: PetKind, screenBounds: CGRect) {
        // Spawns at random position within full screen bounds (both X and Y)
        // Starts with appear animation (opacity 0, scale 0.5)
    }
}
```

### 4.5 PetSpriteSheet (`PetSpriteSheet.swift`)

Loads a sprite sheet image from the asset catalog and extracts individual frames.

```swift
class PetSpriteSheet {
    let image: NSImage                  // Full sprite sheet
    let frameSize: CGSize              // Size of one frame
    let columns: Int                   // Frames per row

    init(kind: PetKind)

    /// Extract a single frame by (row, column)
    func frame(row: Int, column: Int) -> NSImage

    /// Preload all frames for a given state (row) into an array
    func frames(for state: PetState) -> [NSImage]
}
```

Uses `NSImage` cropping (`CGImage.cropping(to:)`) on init to pre-cache all frames
as individual `NSImage` instances. This avoids per-frame cropping overhead.

### 4.6 PetAnimationEngine (`PetAnimationEngine.swift`)

Stateless utility that computes pet updates. Called by `PetManager` on each timer tick.

```swift
@MainActor
enum PetAnimationEngine {
    /// Advance one tick (called at ~15fps). Mutates the PetModel in place.
    static func tick(_ pet: PetModel, dt: TimeInterval, screenBounds: CGRect)

    /// Advance sprite frame counter (slower FPS for sleeping)
    static func stepAnimation(_ pet: PetModel, dt: TimeInterval)

    /// Free 2D roaming: pick random targets, walk toward them, pause, repeat
    static func updateRoaming(_ pet: PetModel, dt: TimeInterval, screenBounds: CGRect)

    /// Idle resting (sitting/working): gently drift toward mouse cursor, rest nearby
    static func updateIdleResting(_ pet: PetModel, dt: TimeInterval, screenBounds: CGRect)

    /// Attention seeking: run toward mouse cursor at higher speed (2D)
    static func updateAttentionSeeking(_ pet: PetModel, dt: TimeInterval, screenBounds: CGRect)

    /// Handle state transitions (reset frames, clear targets on mode change)
    static func updateStateTransition(_ pet: PetModel, newStatus: SessionStatus)

    /// Speech bubble engine (random contextual bubbles with cooldown)
    static func updateSpeechBubble(_ pet: PetModel, dt: TimeInterval)

    /// Clamp position to screen bounds (both X and Y)
    static func clampToScreen(_ pet: PetModel, screenBounds: CGRect)

    /// Resolve collisions between multiple pets (X-axis push-apart)
    static func resolveCollisions(_ pets: [PetModel], minGap: CGFloat)

    /// Calculate normalized 2D velocity toward a target at a given speed
    private static func velocityToward(from: CGPoint, to: CGPoint, speed: CGFloat) -> CGPoint
}
```

**Movement constants (`PetPhysics`):**

```swift
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
    static let idleRetargetInterval: Double = 8  // seconds between mouse re-checks
    static let arrivalThreshold: CGFloat = 30    // idle arrival distance
    static let attentionArrivalThreshold: CGFloat = 40  // attention arrival distance
}
```

### 4.7 PetWindow (`PetWindow.swift`)

Custom `NSPanel` subclass for each pet. Modeled after the existing `FloatingPanel`.

```swift
class PetWindow: NSPanel {
    let petModel: PetModel

    init(petModel: PetModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 128, height: 128),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = false  // We handle dragging ourselves

        // Host the SwiftUI PetView
        contentView = NSHostingView(rootView: PetView(pet: petModel))
    }

    /// Update window position from PetModel.position
    func syncPosition() {
        setFrameOrigin(NSPoint(x: petModel.position.x, y: petModel.position.y))
    }

    /// Resize when pet size preference changes
    func updateSize(_ size: CGFloat) {
        let frame = NSRect(
            x: self.frame.origin.x,
            y: self.frame.origin.y,
            width: size * 2,   // Extra width for name tag overflow
            height: size * 1.5 // Extra height for speech bubble
        )
        setFrame(frame, display: true)
    }
}
```

### 4.8 PetView (`PetView.swift`)

SwiftUI view rendered inside each `PetWindow`.

```swift
struct PetView: View {
    @Bindable var pet: PetModel
    @State private var isHovering = false
    @State private var bubbleOffset: CGFloat = 0  // For bobbing animation

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 2) {
                // Speech bubble (if any)
                if let bubble = pet.speechBubble {
                    SpeechBubble(text: bubble)
                        .offset(y: bubbleOffset)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: bubbleOffset
                        )
                }

                // Sprite
                spriteImage
                    .interpolation(.none)        // Pixel-perfect scaling
                    .scaleEffect(x: pet.facingRight ? 1 : -1, y: 1)

                // Name tag (on hover or always for attention states)
                if isHovering || pet.needsAttention {
                    NameTag(text: pet.displayName)
                        .transition(.opacity)
                }
            }
        }
        .onHover { isHovering = $0 }
        .onAppear { bubbleOffset = -4 }
    }

    private var spriteImage: some View {
        // Render current frame from sprite sheet
        Image(nsImage: pet.currentFrameImage)
            .resizable()
            .frame(width: petSize, height: petSize)
    }
}
```

**Sub-views:**

- `SpeechBubble` (`PetSpeechBubble`) — A dark rounded rect with white bold text.
  Shows attention symbols ("!", "?") or contextual phrases from the speech bubble
  engine. Bobs up and down with a repeating animation.
- `NameTag` (`PetNameTag`) — A tiny capsule with the project name in a small
  monospace font, semi-transparent dark background with white text.

### 4.9 PetManager (`PetManager.swift`)

The top-level coordinator. Created once by `AppDelegate`.

```swift
@MainActor
@Observable
class PetManager {
    private let sessionManager: SessionManager
    private var pets: [String: PetModel] = [:]       // Keyed by session ID
    private var windows: [String: PetWindow] = [:]
    private var spriteSheets: [PetKind: PetSpriteSheet] = [:]
    private var animationTimer: Timer?
    private var enabled: Bool { UserDefaults.standard.bool(forKey: "desktopPetsEnabled") }

    init(sessionManager: SessionManager) {
        self.sessionManager = sessionManager
        preloadSpriteSheets()
        observeSessions()
        startAnimationLoop()
    }

    // --- Session Binding ---

    /// Called when SessionManager.sessions changes.
    /// Diffs current pets vs sessions to create/remove.
    func syncWithSessions(_ sessions: [Session])

    /// Spawn a new pet for a session
    func spawnPet(for session: Session) -> PetModel

    /// Remove a pet (plays disappear animation, then destroys window)
    func despawnPet(id: String)

    // --- Animation Loop ---

    /// 15fps timer that drives all pet updates
    func startAnimationLoop() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) {
            [weak self] _ in
            self?.tick()
        }
    }

    func tick() {
        let dt = 1.0 / 15.0
        let screen = NSScreen.main?.visibleFrame ?? .zero

        // Update each pet
        for pet in pets.values {
            // Sync session status
            if let session = sessionManager.sessions.first(where: { $0.id == pet.id }) {
                pet.session = session
                PetAnimationEngine.updateStateTransition(pet, newStatus: session.status)
            }
            PetAnimationEngine.tick(pet, dt: dt, screenBounds: screen)
        }

        // Resolve collisions
        PetAnimationEngine.resolveCollisions(Array(pets.values), minGap: 20)

        // Sync window positions
        for (id, window) in windows {
            if let pet = pets[id] {
                window.syncPosition()
            }
        }
    }

    // --- Observation ---

    func observeSessions() {
        // Use Combine or withObservationTracking to watch sessionManager.sessions
        // On change: call syncWithSessions()
    }
}
```

### 4.10 PetInteraction (`PetInteraction.swift`)

Handles user input on pet windows. Implemented as an `NSView` subclass used as the
window's content view wrapper, or as gesture recognizers on the hosting view.

```swift
class PetInteractionHandler {
    let pet: PetModel
    let manager: PetManager

    /// Double-click — always jumps to session
    func handleDoubleClick() {
        FocusTerminal.focusSession(pet.session)
    }

    /// Right-click context menu
    func buildContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Jump to Session", action: #selector(jumpToSession), ...)

        let animalMenu = NSMenu()
        for kind in PetKind.allCases {
            let item = NSMenuItem(title: kind.rawValue.capitalized, ...)
            item.state = (kind == pet.kind) ? .on : .off
            animalMenu.addItem(item)
        }
        menu.addItem(withTitle: "Change Animal", submenu: animalMenu)

        let sizeMenu = NSMenu()
        for (label, size) in [("Small", 48), ("Medium", 64), ("Large", 96)] {
            let item = NSMenuItem(title: label, ...)
            item.state = (size == currentPetSize) ? .on : .off
            sizeMenu.addItem(item)
        }
        menu.addItem(withTitle: "Pet Size", submenu: sizeMenu)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide This Pet", action: #selector(hidePet), ...)

        return menu
    }

    /// Drag handling — pet stays where dropped permanently (no freeze timer)
    func handleDragBegan(at point: NSPoint)
    func handleDragMoved(to point: NSPoint)
    func handleDragEnded() {
        pet.isDragging = false
        // Pet stays where dropped — no dragFrozenUntil
    }
}
```

### 4.11 AppDelegate Integration

Minimal changes to `AppDelegate.swift`:

```swift
// In applicationDidFinishLaunching, after SessionManager init:
private var petManager: PetManager?

func setupPetManager() {
    petManager = PetManager(sessionManager: sessionManager)
}

// Observe preference changes to enable/disable
func observePetPreferences() {
    // When "desktopPetsEnabled" changes:
    //   true  -> petManager.enable()  (start spawning pets)
    //   false -> petManager.disable() (despawn all pets)
}
```

### 4.12 Settings Integration

Add to `SettingsSection.swift`, inside the existing settings VStack:

```swift
// --- Desktop Pets ---
Divider()
HStack {
    Text("Desktop Pets")
    Spacer()
    Toggle("", isOn: $desktopPetsEnabled)
        .toggleStyle(.switch)
}

if desktopPetsEnabled {
    HStack {
        Text("Pet Size")
        Spacer()
        Picker("", selection: $desktopPetSize) {
            Text("Small").tag(48)
            Text("Medium").tag(64)
            Text("Large").tag(96)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
    }
}
```

---

## 5. Implementation Order

Work proceeds in layers, each producing a testable milestone:

### Phase 1: Window & Rendering (days 1–2)

1. **PetKind + PetState** — Enums with all metadata.
2. **PetModel** — Observable class with all properties, placeholder init.
3. **PetWindow** — NSPanel subclass. Verify: a transparent, borderless, floating
   window appears on screen and can be moved programmatically.
4. **PetView** — SwiftUI view with a placeholder colored rectangle. Verify: the
   rectangle renders in the transparent window.
5. **Dragging** — Implement mouseDown/mouseDragged/mouseUp. Verify: the window
   follows the cursor when dragged.

*Milestone: A colored square floats on the desktop and can be dragged around.*

### Phase 2: Sprites & Animation (days 3–4)

6. **PetSpriteSheet** — Atlas loader. Write a unit test that loads a test image and
   extracts frames.
7. **Placeholder sprites** — Programmatically generated sprite sheet PNGs (or simple
   SF Symbol sequences).
8. **Frame animation** — Wire PetView to cycle through frames from the sprite sheet
   based on PetState. Verify: the placeholder animates at ~10fps.
9. **State-to-animation mapping** — PetState.init(from: SessionStatus) and the
   sprite row/frame-count metadata.

*Milestone: An animated placeholder pet cycles through different animation states.*

### Phase 3: Movement & AI (days 5–6)

10. **PetAnimationEngine.tick()** — Core update loop.
11. **Free 2D roaming** — Random walk across full screen (both axes) with pauses and turning.
12. **Idle resting** — Working pets gently drift toward mouse cursor, rest nearby.
13. **Attention-seeking** — Run toward mouse cursor in 2D at higher speed.
14. **Screen clamping** — Stay within screen bounds (both X and Y, 20pt margin).
15. **Collision avoidance** — Push overlapping pets apart (X-axis).
16. **Speech bubbles** — Contextual random bubbles with cooldown engine.

*Milestone: The pet roams the screen autonomously in 2D, chases the mouse cursor when
needing attention, and respects screen edges.*

### Phase 4: Session Binding (day 7)

16. **PetManager** — Create/destroy pets as sessions appear/disappear.
17. **Session sync** — Update pet.session on each tick from SessionManager.
18. **State transitions** — Drive pet state changes from session status changes.
19. **Multi-pet** — Verify multiple pets coexist without overlapping.

*Milestone: Real sessions spawn pets that reflect live session status.*

### Phase 5: Interaction (day 8)

20. **Double-click handler** — Double-click any pet -> FocusTerminal.focusSession().
21. **Right-click menu** — Context menu with Jump, Change Animal, Size, Hide.
22. **Hover tooltip** — Name tag appears on hover.
23. **Drag** — Pet stays where dropped permanently (no freeze timer).

*Milestone: Pets are fully interactive — click to jump, right-click for options.*

### Phase 6: Settings & Polish (day 9)

24. **Settings toggle** — Add to SettingsSection. Wire enable/disable.
25. **Pet size preference** — Small/Medium/Large, updates window + sprite size.
26. **Spawn/despawn animations** — Fade-in on appear, shrink-out on disappear.
27. **Speech bubble polish** — Bobbing animation, proper sizing.
28. **Edge cases** — No sessions, all sessions die, rapid session churn.

*Milestone: Feature-complete with settings integration.*

### Phase 7: Real Sprites (day 10+)

29. **Source or create** pixel-art sprite sheets for dog, cat, hamster.
30. **Integrate** into asset catalog.
31. **Tune** frame counts, animation speeds, per-animal personality.

*Milestone: Shippable feature with real art.*

### Testing Philosophy

Tests are kept minimal — basic smoke tests only. The priority is getting functional
quickly. Tests cover: enum completeness, init sanity, basic tick lifecycle, and
clamp/collision no-crash assertions. Comprehensive tests can be added later once the
feature is stable and the API is settled.

---

## 6. What Changes in Existing Code

**Minimal.** The feature is almost entirely additive.

| File | Change |
|------|--------|
| `AppDelegate.swift` | Add `petManager` property, init it after `sessionManager`, observe pet preferences |
| `SettingsSection.swift` | Add "Desktop Pets" toggle and "Pet Size" picker |
| `Assets.xcassets` | Add `Pets/` folder with sprite sheet image sets |
| `CctopMenubar.xcodeproj` | New files added to the CctopMenubar target (not cctop-hook) |

No changes to:
- Session model or session file format
- Hook handler (cctop-hook)
- opencode plugin
- Raycast extension
- SessionManager, HistoryManager, or any existing service
- Any existing view besides SettingsSection

---

## 7. Technical Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Transparent floating windows may be janky on older Macs | Use `NSPanel` (proven by FloatingPanel), keep sprite size small, cap at 15fps |
| Multiple pet windows may impact battery | Share a single `Timer` for all pets. Consider pausing animation when no sessions are active or screen is locked |
| Dragging may conflict with system drag targets | Use `NSPanel.isMovableByWindowBackground = false` and handle dragging manually with precise hit testing |
| Window ordering issues (pets appearing above fullscreen apps) | Use `.fullScreenAuxiliary` in collection behavior; test with fullscreen and mission control |
| Sprite art sourcing | Start with programmatic placeholders; the system works without real art. Commission or source sprites independently |
| Screen coordinate confusion (AppKit's bottom-left vs SwiftUI's top-left) | PetModel uses AppKit screen coordinates (bottom-left origin) consistently; PetView is agnostic |

---

## 8. Future Extensions (Not in v1)

- **Sound effects** — Optional bark/meow/squeak sounds for attention states.
- **More animals** — Rabbit, bird, fish (in a bowl!), snake.
- **Personality traits** — Some pets are lazier (longer pauses), some are hyperactive
  (faster roaming). Randomly assigned alongside animal kind.
- **Pet-to-pet interaction** — Pets notice each other: cats hiss at dogs, hamsters
  hide behind other pets.
- **Cursor awareness** — Pets notice the cursor: cats may chase it, dogs may follow
  it briefly.
- **Desktop furniture** — Tiny pixel-art objects (food bowl, bed, toy) that pets
  interact with at their resting spot.
- **Session name in bubble** — When attention-seeking, show the prompt or
  notification message in the speech bubble.
- **Growl/notification integration** — Pet attention state triggers a native macOS
  notification with the pet's icon.
