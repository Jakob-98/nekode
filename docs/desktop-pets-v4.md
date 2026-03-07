# Desktop Pets v4: Current State

Small pixel-art animals (dog, cat, hamster) that live on the macOS desktop,
one per active coding session. Each pet mirrors its session's real-time
status through behavior, animation, and speech. You can drag them around,
double-click to jump to the session's terminal, and dismiss alerts by
picking them up.

v1 established the concept and status-to-behavior mapping. v2 made a single
pet feel alive — idle breathing, physics-based movement, squash/stretch,
dust particles. v3 added multi-pet polish — vibe zone layout, collision
resolution, gathering, attention spacing. This doc describes the system as
it exists today, including all three session sources and the full behavior
repertoire.

---

## Session Sources

Pets are driven by JSON files in `~/.cctop/sessions/`. Any process that
writes a conforming JSON file gets a pet. Three sources exist today:

### Claude Code (`cctop-hook`)

A Swift CLI (`cctop-hook`) installed as a Claude Code hook. CC invokes it on
every lifecycle event (SessionStart, UserPromptSubmit, PreToolUse,
PostToolUse, Stop, Notification, PermissionRequest, PreCompact, SessionEnd).
The hook reads event JSON from stdin, walks the process tree to find the
parent PID (skipping shell intermediaries), and writes/updates the session
file at `~/.cctop/sessions/{pid}.json`.

Key behaviors:
- **PID walking:** Traverses up to 4 parent processes past sh/bash/zsh/fish
  to find the real parent PID
- **Terminal detection:** Reads `TERM_PROGRAM`, `ITERM_SESSION_ID`,
  `KITTY_WINDOW_ID` from env; walks parent chain for TTY via
  `devname(tdev, S_IFCHR)`
- **Session name lookup:** Reads the CC transcript file to extract the
  session name
- **Tool tracking:** Maps tool names to display detail
  (bash -> command, edit -> file_path, etc.)
- **Stale cleanup:** On session start, removes dead session files for the
  same project

### opencode (JavaScript plugin)

A zero-dependency JS plugin at `~/.config/opencode/plugins/cctop.js`. Runs
in-process in Bun. Hooks into opencode's event system:

- `session.created/idle/error/compacted/status/updated/deleted`
- `chat.message` — captures prompt, sets working
- `tool.execute.before/after` — tracks tool usage, handles Question tool
  as `waiting_input`
- `permission.ask/replied` — permission flow
- `experimental.session.compacting`

Maps opencode's `"idle"` event to `waiting_input` (since opencode is always
interactive — idle means waiting for user input, not sleeping).

### petwait (pipe-based CLI)

A CLI tool for monitoring arbitrary commands. Usage:

```
some-long-command | petwait --name "building"
```

Creates a session with `source: "cli"`, passes stdin through to stdout
while updating `lastActivity` every 5 seconds. When the piped command
finishes (stdin EOF), transitions to `waiting_input` with "Command
finished" notification and waits for the user to press Enter (reads from
`/dev/tty`, not stdin). Handles SIGINT/SIGTERM to clean up the session
file.

Terminal detection works the same as cctop-hook (env vars + parent chain
TTY walk).

---

## Session Discovery

`SessionManager` watches `~/.cctop/sessions/` via:
- **Filesystem events:** `DispatchSource.makeFileSystemObjectSource` with
  100ms debounce
- **Polling:** 2-second `Timer` for liveness checks

Session liveness requires:
1. PID exists (`kill(pid, 0)`)
2. PID hasn't been reused (compares stored `pidStartTime` vs current)
3. Process isn't orphaned (parent != launchd, i.e. terminal still alive)

Dead sessions are archived to `~/.cctop/history/` and their JSON files
removed.

---

## Pet Lifecycle

### Spawn

When a new session appears in `syncWithSessions`:
1. Skip if pet ID is in `hiddenPetIds` (user hid it via context menu)
2. Pick a random `PetKind` (dog/cat/hamster)
3. Create `PetModel` with position off-screen right (`screenBounds.maxX + 40`)
4. Set `isRunningIn = true` with a `runInTarget` inside the vibe zone
5. Create `PetWindow` (NSPanel) and `PetView` (SwiftUI)
6. Pet runs in from the right edge toward its target at 140 pt/s

### Steady State

The 15 FPS animation timer calls `PetAnimationEngine.tick()` per pet each
frame. The engine updates movement, animation frames, particles, speech
bubbles, squash/stretch, and screen clamping. `PetManager` then syncs
window positions and resolves collisions.

### Despawn

When a session disappears:
1. Set `isDisappearing = true`
2. Fade out opacity and shrink scale over 300ms
3. When opacity hits 0, set `shouldRemove = true`
4. `PetManager.tick()` removes the pet and closes its window

### Hide

User can hide a pet via context menu. The pet ID is added to `hiddenPetIds`
(persisted in UserDefaults). Hidden pets won't respawn on session updates.
Hidden IDs are cleaned up when their sessions end.

---

## States and Transitions

### SessionStatus -> PetState Mapping

| SessionStatus       | PetState     | Behavior                          |
|----------------------|--------------|-----------------------------------|
| `idle`               | `.sleeping`  | Zzz particles, slow drift         |
| `working`            | `.sitting`   | Idle tiers, vibe zone wander      |
| `compacting`         | `.spinning`  | Spin animation, stationary        |
| `waitingInput`       | `.alerting`  | 4-stage attention escalation      |
| `needsAttention`     | `.alerting`  | Same as waitingInput              |
| `waitingPermission`  | `.barking`   | 4-stage attention escalation      |

Two additional PetState values (`.walking`, `.running`) are visual-only —
never set as actual state. `.walking` is returned by the `visualState`
computed property when the pet is `.sitting` but has nonzero velocity
(walking to its home spot). `.running` is dead code (reserved for future
sprint animations).

`.appearing` and `.disappearing` are lifecycle-only states for spawn/despawn
fade.

### State Transition Logic

`PetAnimationEngine.updateStateTransition(pet, newStatus:)`:
- If user dismissed this status by dragging, ignore until status changes
- Map new status to PetState; skip if same as current
- Reset `currentFrame`, `frameAccumulator`, `idleTime`
- Save/restore `preChaseHome` when entering/leaving attention-seeking
- Reset `target` when switching between attention-seeking and non-attention
- Reset roaming timers when entering a moving state

### Dismissed Status

When the user drag-dismisses an attention-seeking pet, `dismissedStatus` is
set to the current session status. The engine ignores status updates that
match `dismissedStatus`. Once the session status changes to something
different, `dismissedStatus` clears and normal transitions resume.

---

## Behaviors

### Vibe Zone

A 200x120pt shared hangout area where all pets congregate. Defaults to
lower-right corner of screen, offset 40pt from edges. Position persisted
via UserDefaults (`vibeZoneX`, `vibeZoneY`). Moveable via context menu to
lower-left, lower-right, or bottom-center.

Pets without a custom home (not dragged by user) wander within the vibe
zone. When the vibe zone moves, all non-custom-home pets get new targets
inside the new zone.

### Idle Resting (sitting/working)

Pets in `.sitting` state walk toward their home spot (inside vibe zone or
custom drag position) at `vibeWanderSpeed` (40 pt/s). On arrival:
1. Trigger settle squash (1.08x, 0.92y, 120ms)
2. Spawn dust particles
3. Pause for 3-10 seconds
4. Pick a new random wander target inside the vibe zone
5. Repeat

Custom-home pets (user dragged) walk to their drag position and stay there
until dragged again or returned to vibe zone via context menu.

### Idle Tier System

Time accumulates continuously while in `.sitting` state (including during
vibe zone wander pauses):

| Tier | Idle Time | Behavior                                    |
|------|-----------|---------------------------------------------|
| 0    | 0-5s      | Just sat down, no speech bubbles yet         |
| 1    | 5-30s     | Attentive — tool activity bubbles, "coding..." |
| 2    | 30-120s   | Bored — "still coding...", "*yawn*", "bored..." |
| 3    | 120s+     | Drowsy — "sleepy...", "zzz...", "*nods off*" |

After 180s at tier 3+, the pet transitions from `.sitting` to `.sleeping`.

### Sleeping

Sleeping pets display Zzz particles and use slowed animation (0.3x normal
FPS). They drift very slowly within the vibe zone:
- Pause for 20-45s (initial) / 30-60s (between drifts)
- Pick a random nearby point in the vibe zone
- Drift toward it at 12 pt/s
- On arrival, pause again

Sleep drift uses separate `sleepDriftTarget`/`sleepDrifting` fields to
avoid clobbering the pet's home position (`lastDropPosition`).

Custom-home sleeping pets don't move.

### Attention Seeking (4-stage escalation)

When the session enters `waitingInput`, `needsAttention`, or
`waitingPermission`, the pet begins escalating:

| Stage | Time    | Behavior                                          |
|-------|---------|---------------------------------------------------|
| 1     | 0-10s   | Perk up: stay at home, face the cursor             |
| 2     | 10-30s  | Approach: walk toward cursor at 60 pt/s, stop ~50px away |
| 3     | 30-60s  | Insistent: faster approach at 100 pt/s, stop ~30px away |
| 4     | 60s+    | Urgent: run at 120 pt/s, stop ~20px away, bounce in place every 0.6-1.0s |

**Multi-pet spacing:** When multiple pets seek attention simultaneously,
they spread evenly around the cursor in a 180-degree arc. Each pet gets an
offset angle so they don't pile up.

**Pre-chase home:** When entering attention-seeking, the pet saves its
current `lastDropPosition` as `preChaseHome`. On drag-dismiss or natural
status change, the saved home is restored.

**Run-in abort:** If attention-seeking status arrives while the pet is still
running in from the screen edge, the run-in is immediately aborted so the
pet can chase the cursor.

### Run-In (spawn animation)

New pets spawn off-screen right and run toward a random point in the vibe
zone at 140 pt/s. On arrival: settle squash (1.12x, 0.88y, 120ms) + dust.
During run-in, the pet uses the walking/running sprite and updates position,
animation, and particles normally.

### Roaming (free wander)

Steering-behavior approach with smooth curved paths:
1. Pick a random desired heading every 3-8s
2. Smoothly rotate current heading toward desired (2 rad/s turn speed)
3. Apply speed along current heading (70 pt/s)
4. Edge repulsion within 80px of screen edges (repulsion vector, not clamp)
5. 15% chance per direction change to pause for 1-3s
6. Gathering bias: if sitting pets exist beyond `gatheringRadius` (120px),
   steer toward their centroid

### Collision Resolution

O(n^2) pairwise check each tick. If two pet centers are within
`personalSpace` (60px), push each apart by half the overlap along their
connection axis. Dragged pets are excluded.

---

## Visual Features

### Sprite Sheets

Three animals, each with a single PNG sprite sheet in the asset catalog
(served at @2x: 48x48px per cell, renders at 24x24pt). All sprites face
right; left-facing achieved via `scaleEffect(x: -1)`.

| Row | Animation | Frames | Loop | Notes                    |
|-----|-----------|--------|------|--------------------------|
| 0   | Sit/Idle  | 4      | Yes  | Base sitting animation   |
| 1   | Walk      | 6 (4 hamster) | Yes | Full walk cycle    |
| 2   | Run       | 6 (4 hamster) | Yes | Faster gait        |
| 3   | Sleep     | 2      | Yes  | Chest rise/fall          |
| 4   | Alert/Bark| 4      | Yes  | Head up, ears perked     |
| 5   | Special   | 4      | Yes  | Spin (compacting)        |

Animation runs at 8 FPS (all kinds). Sleeping uses 0.3x speed (2.4 FPS).

`SpriteSheetCache` (singleton) pre-caches cropped `NSImage` frames keyed by
`"kind-row-column"`. Falls back to `PlaceholderSprite` (SF Symbols) if
sheets aren't in the asset catalog.

### Squash and Stretch

Triggered on events, eases linearly back to 1.0 over the specified duration:

| Event              | scaleX | scaleY | Duration |
|--------------------|--------|--------|----------|
| Landing after drag | 1.15   | 0.85   | 100ms    |
| Run-in arrival     | 1.12   | 0.88   | 120ms    |
| Walk arrival       | 1.08   | 0.92   | 120ms    |
| Direction change   | 1.05   | 0.95   | 60ms     |
| Stage 4 bounce     | 0.9    | 1.12   | 100ms    |

### Dust Particles

3-5 small circles spawned at the pet's feet on landing, arrival, and
direction changes. Each particle:
- Starts at random offset (-8...8, -2...4)
- Drifts upward at 20 pt/s
- Expands slightly over lifetime
- Fades from full opacity to 0
- Lifetime: 200-400ms

### Zzz Particles

Floating letters ("z", "Z") spawned every 2-3s while sleeping:
- Start near pet's upper-right (4-12px right, 4-8px above center)
- Float upward at 18 pt/s, drift right at 6 pt/s
- Grow slightly (1.5 pt/s)
- Fade in over first 20% of lifetime, hold, fade out over last 30%
- Lifetime: 2-3s
- Cleared immediately when leaving sleep state

### Breathing Bob

Sinusoidal vertical oscillation on the sprite: `sin(t * 2pi / 2.5s)`.
Displacement scales with pet size (~1.5px at 64pt). Always active, even
during movement (additive with position).

### Shadow

Static dark ellipse below the sprite: `0.6 * petSize` wide,
`0.15 * petSize` tall, 25% black opacity, 1.5px blur.

### Speech Bubbles

Short contextual messages in a rounded-rect bubble above the pet's head.
Slide+fade entrance animation (200ms ease-out).

**Content by state:**

| State    | Tier/Stage | Content                                          |
|----------|------------|--------------------------------------------------|
| Sitting  | Tier 1     | Tool activity ("editing auth.ts") or "coding...", "thinking..." |
| Sitting  | Tier 2     | "still coding...", "*yawn*", "bored..."           |
| Sitting  | Tier 3     | "sleepy...", "zzz...", "*nods off*"                |
| Sleeping | --         | None (Zzz particles handle it)                    |
| Alerting | Stage 1    | Notification message (truncated to 20 chars) or "?" |
| Alerting | Stage 2    | Notification message or "need input"               |
| Alerting | Stage 3    | "hey!", "over here!", "need input"                 |
| Alerting | Stage 4    | "!!"                                               |
| Barking  | Stage 1-4  | "?" -> "approve?" -> "approve!!" -> "!!!"          |
| Spinning | --         | "compacting..."                                    |

**Tool activity bubbles** (sitting tier 1-2):
- Bash: `$ command` (first 18 chars)
- Edit/Write/Read: `editing/writing/reading filename` (14 chars)
- Grep/Glob: "searching..."
- Task: "delegating..."
- WebFetch/WebSearch: "browsing..."

**Cooldowns:**
- Attention-seeking: 20-40s (stage 1) -> 12-25s (2) -> 6-12s (3) -> 3-6s (4)
- Idle: 45-90s (tier 1) -> 20-45s (tier 2) -> 15-30s (tier 3)
- Show duration: 2.5-4s per bubble

### Name Tag

Monospaced text in a dark capsule below the sprite. Shows
`session.displayName` (session name or project name, max 30 chars).
Visible on hover or when the pet needs attention. Font: 7pt medium
monospaced.

---

## Interaction

### Double-Click

Focuses the session's terminal/editor. Uses `FocusTerminal` which:
1. Tries to match by `terminal.program` + `terminal.sessionId` (iTerm, Kitty)
2. Falls back to activating the terminal app by bundle ID
3. Falls back to `NSWorkspace.shared.open` for the project directory

### Right-Click Context Menu

| Item                | Action                                            |
|---------------------|---------------------------------------------------|
| Jump to Session     | Same as double-click                              |
| Change Animal >     | Submenu: Dog, Cat, Hamster (checkmark on current) |
| Pet Size >          | Submenu: Small (48pt), Medium (64pt), Large (96pt)|
| Vibe Zone >         | Move to Lower-Left / Lower-Right / Bottom-Center  |
| Return to Vibe Zone | Only shown if pet has custom home from dragging    |
| Hide This Pet       | Removes pet, persists in `hiddenPetIds`           |

### Drag

- Grab: sets `isDragging = true`, records start position
- Drag: moves pet position directly (screen coordinates, Y-up)
- Drop: triggers landing squash + dust

**If attention-seeking:** Drag-dismiss. Saves `dismissedStatus`, restores
`preChaseHome`, sets state to `.sitting` (or `.sleeping` if session is
idle), resets attention timer.

**If not attention-seeking:** Sets `lastDropPosition` to drop location,
marks `hasCustomHome = true`. Pet stays where dropped.

### Hover

Shows the name tag below the sprite (opacity toggle, always in layout).

---

## Windowing

Each pet lives in its own `PetWindow` (NSPanel subclass):

- **Style:** `.borderless`, `.nonactivatingPanel` — no title bar, never
  steals focus
- **Level:** `.floating` — above normal windows
- **Background:** Fully transparent, no shadow
- **Collection behavior:** `canJoinAllSpaces`, `stationary`,
  `fullScreenAuxiliary` — visible on all Spaces, doesn't move with spaces
- **Size:** `petSize * 2` wide, `petSize * 2.5` tall (room for speech
  bubble + name tag)
- **Hit testing:** Custom hit rect covering only the sprite area
  (`petSize * 0.7` square) plus name tag. Clicks outside pass through to
  apps behind.
- `canBecomeKey: true` (for gesture delivery), `canBecomeMain: false`
- `hidesOnDeactivate: false` — stays visible when app loses focus

---

## Configuration

| UserDefaults Key      | Type     | Default  | Notes                    |
|-----------------------|----------|----------|--------------------------|
| `desktopPetsEnabled`  | Bool     | false    | Master toggle            |
| `desktopPetSize`      | Int      | 64       | 48, 64, or 96           |
| `vibeZoneX`           | Double   | --       | Custom vibe zone X origin|
| `vibeZoneY`           | Double   | --       | Custom vibe zone Y origin|
| `hiddenPetIds`        | [String] | []       | Pet IDs hidden by user   |

---

## Physics Constants

| Constant              | Value     | Used For                          |
|-----------------------|-----------|-----------------------------------|
| `roamSpeed`           | 70 pt/s   | Free roaming                      |
| `attentionSpeed`      | 120 pt/s  | Stage 4 cursor chase              |
| `idleWalkSpeed`       | 60 pt/s   | Walking to home / stage 2 approach|
| `runInSpeed`          | 140 pt/s  | Spawn run-in from screen edge     |
| `vibeWanderSpeed`     | 40 pt/s   | Gentle wander inside vibe zone    |
| `sleepDriftSpeed`     | 12 pt/s   | Very slow sleeping drift          |
| `acceleration`        | 300 pt/s^2| How fast pet reaches max speed    |
| `deceleration`        | 400 pt/s^2| How fast pet stops                |
| `personalSpace`       | 60 pt     | Min center-to-center distance     |
| `gatheringRadius`     | 120 pt    | Idle pet drift-toward-each-other  |
| `edgeMargin`          | 20 pt     | Distance from screen edges        |
| `arrivalThreshold`    | 20 pt     | "Close enough" to target          |
| `appearDuration`      | 0.4s      | Fade-in time                      |
| `disappearDuration`   | 0.3s      | Fade-out time                     |

---

## File Structure

```
menubar/CctopMenubar/Pets/
  PetKind.swift              # Animal enum (dog/cat/hamster), sprite metadata
  PetState.swift             # 9-case state enum, SessionStatus mapping
  PetModel.swift             # Per-pet state: position, velocity, idle tiers,
                             #   attention stages, particles, speech, squash
  PetAnimationEngine.swift   # Stateless tick engine: all movement, physics,
                             #   behaviors, particles, speech bubbles (~1100 lines)
  PetView.swift              # SwiftUI: sprite + shadow + dust + zzz + speech
                             #   bubble + name tag + AppKit mouse handler
  PetWindow.swift            # NSPanel: non-activating, click-through, floating
  PetManager.swift           # Coordinator: spawn/despawn, 15fps timer, vibe zone,
                             #   context menu, hidden pets, session sync
  SpriteSheetView.swift      # Sprite sheet cache + CGImage frame extraction

menubar/CctopMenubar/Hook/
  HookMain.swift             # cctop-hook CLI entry point
  HookHandler.swift          # Event processing, PID walking, terminal detection
  HookInput.swift            # Hook JSON input parsing
  HookLogger.swift           # Hook event logging

menubar/CctopMenubar/PetWait/
  PetWaitMain.swift          # petwait CLI: session lifecycle, terminal detection
  PipeMonitor.swift          # stdin->stdout passthrough with activity updates

menubar/CctopMenubar/Models/
  Session.swift              # Session struct, liveness check, file I/O
  SessionStatus.swift        # 6-case status enum
  HookEvent.swift            # Hook event enum + state transition table

menubar/CctopMenubar/Services/
  SessionManager.swift       # Session discovery: fs watcher + 2s polling
  FocusTerminal.swift        # Terminal/editor focusing (double-click)
  PluginManager.swift        # opencode plugin installation

plugins/opencode/plugin.js   # opencode session tracking plugin
```

---

## What's Next

Ideas for future work, roughly ordered by impact:

### Richer idle animations
The sprite sheets have 6 rows but the idle behavior is just the sitting
loop + speech bubbles. With more sprite rows (yawn, scratch, stretch,
look around), each idle tier could trigger distinct fidget animations.
The engine already has `idleTier` — it just needs more frames to play.

### Pet personality
Same state machine, different constants. A lazy cat pauses longer between
wanders. A nervous hamster has shorter idle tier thresholds. A loyal dog
approaches faster in attention stage 2. Currently all three animals share
identical timing.

### Project -> animal persistence
Same project should always get the same animal across sessions. Currently
it's random on each spawn.

### Pet-to-pet awareness
Pets could glance at each other when nearby, react when a sibling enters
attention-seeking, or huddle together during long idle periods. The
collision and gathering systems provide the spatial foundation.

### Richer attention behaviors
Screen-edge bouncing, window-edge perching, configurable urgency levels,
"snooze" gesture (push to edge = "not now, ask in 5 minutes").

### Celebration animation
Trigger a happy bounce/tail wag when a task completes or tests pass.
Would need a new sprite row and a "task completed" session event.

### Sound effects
Optional per-status sounds. Must be toggleable and off by default.
