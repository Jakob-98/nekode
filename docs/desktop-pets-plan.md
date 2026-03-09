# Desktop Pets

Small pixel-art animals that live on the macOS desktop, one per active coding
session. Each pet visually reflects its session's status and lets you interact
with it directly — no need to open the menubar popup.

## How It Works

When Desktop Pets is enabled in Settings, each active session gets a pet (dog,
cat, or hamster, randomly assigned). Pets spawn near the top of the screen and
walk, sleep, or chase your cursor depending on what the session is doing.

### Status-to-Behavior Mapping

| Session Status       | Pet Behavior                                       |
|----------------------|----------------------------------------------------|
| `idle`               | Sleeping in place (slow breathing animation)       |
| `working`            | Walks to its home spot, then sits (chilling)       |
| `compacting`         | Spins in place                                     |
| `waitingInput`       | Runs toward mouse cursor, shows "?" bubble         |
| `waitingPermission`  | Runs toward mouse cursor, shows "!" bubble         |
| `needsAttention`     | Same as `waitingInput`                             |

The "home spot" is wherever the user last dropped the pet (or its spawn
position). Working pets walk there and rest — they don't follow the mouse.

### Interaction

| Gesture       | Effect                                              |
|---------------|-----------------------------------------------------|
| Double-click  | Jump to session terminal                            |
| Drag          | Reposition pet; it stays where dropped (new home)   |
| Drag (alert)  | Dismisses the alert — pet sleeps at drop location   |
| Right-click   | Context menu (jump, change animal, size, hide)      |
| Hover         | Shows project name tag below pet                    |

Dragging an attention-seeking pet counts as "I saw it" — the pet transitions
to sleeping and won't re-alert until the session status actually changes.

### Speech Bubbles

Pets occasionally show short contextual messages ("coding...", "zzz",
"approve?"). Bubbles have a 45-90 second cooldown between appearances and a
15-second initial delay after spawn to avoid visual noise.

## Architecture

All code lives in `menubar/CatAssistant/Pets/` (8 files, ~1400 lines total).
No separate Xcode target — pets are part of the menubar app.

```
Pets/
  PetKind.swift             # Animal enum (dog/cat/hamster) + sprite metadata
  PetState.swift            # Animation state enum, SessionStatus mapping
  PetModel.swift            # Per-pet state (position, velocity, home, dismissed)
  PetAnimationEngine.swift  # Movement physics, roaming, attention-seeking, bubbles
  PetView.swift             # SwiftUI view + AppKit mouse handling (PetMouseView)
  PetWindow.swift           # NSPanel subclass (transparent, floating, non-activating)
  PetManager.swift          # Lifecycle: session binding, animation timer, context menu
  SpriteSheetView.swift     # Sprite sheet cache + frame extraction
```

### Key Design Decisions

**AppKit mouse handling.** SwiftUI gestures don't work through non-activating
`NSPanel`. All mouse interaction (drag, double-click, right-click) is handled
by `PetMouseView`, an `NSView` subclass with `acceptsFirstMouse = true`.

**ZStack layout.** Speech bubble and name tag are overlaid at fixed offsets
relative to the sprite, not stacked in a VStack. This prevents the sprite from
jumping vertically when overlays appear/disappear.

**`visualState` computed property.** Returns `.walking` when logical state is
`.sitting` but velocity is non-zero. This plays the walking animation while the
pet is en route to its home spot without adding a new enum case.

**`dismissedStatus` field.** Prevents the animation engine from re-alerting a
pet after the user drags to dismiss. Clears when the session status changes to
something different.

**Spawn position.** Near the top of the screen (menubar area), random X.

### Integration Points

- `AppDelegate.swift` — `petManager` property + `setupPetManager()`
- `SettingsSection.swift` — Desktop Pets toggle + Pet Size picker
- Asset catalog — `Pets/` folder with dog/cat/hamster sprite sheets (1x + 2x)

No changes to session models, hook handlers, plugins, or existing views
(besides Settings).

### Sprites

Each animal has a single PNG sprite sheet (6 rows x 4-6 columns, 24x24pt
cells, served at @2x from the asset catalog). Rows map to animation states:

| Row | Animation | Frames |
|-----|-----------|--------|
| 0   | Sit/Idle  | 4      |
| 1   | Walk      | 4-6    |
| 2   | Run       | 4-6    |
| 3   | Sleep     | 2      |
| 4   | Alert     | 4      |
| 5   | Special   | 4      |

All sprites face right. Left-facing is achieved by flipping at render time.
`SpriteSheetCache` pre-caches cropped frames to avoid per-tick CGImage work.
Falls back to `PlaceholderSprite` (SF Symbols) if sheets aren't in the catalog.

### Movement Physics

Constants in `PetPhysics`:

| Constant            | Value   | Used For                    |
|---------------------|---------|-----------------------------|
| `roamSpeed`         | 70 pt/s | Free roaming                |
| `idleWalkSpeed`     | 50 pt/s | Walking to home spot        |
| `attentionSpeed`    | 100 pt/s| Chasing mouse cursor        |
| `edgeMargin`        | 20 pt   | Distance from screen edges  |
| `arrivalThreshold`  | 30 pt   | "Close enough" to home      |
| `collisionGap`      | 20 pt   | Minimum distance between pets|

Pets are clamped to screen bounds on both axes. Collision resolution pushes
overlapping pets apart on the X axis.

## Settings

- **Desktop Pets** toggle (default: OFF)
- **Pet Size** picker: Small (48pt), Medium (64pt, default), Large (96pt)

Both stored via `@AppStorage` / `UserDefaults`.

## What's Not Built Yet

Ideas for where this could go, roughly ordered by impact:

### Clippy-style agent assistant
The highest-leverage direction. Instead of just mirroring status, pets could
surface useful information — show the current tool being run, display a
summary of what the agent just did, or preview the permission request text
in the speech bubble so you can approve/deny without switching windows.

### Richer attention behavior
- Pets could knock on the screen edge or bounce against it when attention is
  needed, not just chase the cursor
- Configurable urgency levels — gentle nudge vs. insistent barking
- A "snooze" gesture (e.g., push pet to screen edge = "not now, ask again
  in 5 minutes")

### Persistence and identity
- Remember which animal was assigned to which project across sessions
- Let users name their pets
- Track basic stats (how long it's been alive, how many sessions it's seen)

### Pet-to-pet awareness
- Pets notice each other when close — cats hiss at dogs, hamsters huddle
- Queue near each other when multiple sessions need attention simultaneously

### More animals
Rabbit, bird, fish (in a bowl), snake. Each with unique personality traits
(lazier pauses, faster roaming, unique alert animations).

### Sound effects
Optional per-status sounds — bark for permission, meow for input needed,
quiet snore for sleeping. Must be toggleable and off by default.

### Notification integration
Pet attention state triggers a native macOS notification with the pet's icon
and the session's prompt/permission text.
