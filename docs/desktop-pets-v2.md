# Desktop Pets v2: POC → MVP

The v1 POC proved the concept works — pixel-art animals that mirror agent
session status, living on the macOS desktop. But it feels robotic. Pets move
in straight lines, snap between states, have no body language, and sit
perfectly still when idle. This doc covers what it takes to make one pet
look and feel great before scaling back to multiple.

**Scope:** One animal (dog), polished to the point where you'd want to show
someone. Multiple pets come after the foundation is solid.

## What "Great" Looks Like

Watch a Tamagotchi, a Stardew Valley pet, or a Shimeji. What they all share:

1. **Pets are never perfectly still.** Even idle, they breathe, blink, twitch
   an ear, glance around. The absence of motion is itself a state (dead).
2. **Transitions are animated.** Waking up has a stretch. Sitting down has a
   settle. Running starts with a lean. Stopping has overshoot.
3. **Motion has physics.** Acceleration, deceleration, overshoot on stop.
   Not constant-velocity straight lines.
4. **Personality comes from timing.** A lazy cat pauses longer. A nervous
   hamster twitches more. Same state machine, different constants.
5. **Small details compound.** A shadow grounds it. A dust puff on landing
   sells the weight. A gentle bob when idle sells the life.

## Prior Art: What Works

### Clippy / Microsoft Agent (~70 animation states)

The most relevant prior art. Three key insights:

- **Tiered idle system.** Level 1 (0-30s): blinks, glances. Level 2
  (30-120s): fidgets, stretches. Level 3 (120s+): yawns, falls asleep.
  This creates a natural narrative: attentive → bored → sleepy.
- **Return animations.** Every action has an exit that blends back to
  neutral. `GetAttention` → `GetAttentionReturn` → idle. No hard cuts.
- **Animation queue.** Actions are queued and executed in order, not
  interrupted. Current action plays to completion (or a clean exit point)
  before the next one starts.

Why Clippy failed: it interrupted you. It appeared uninvited with unwanted
advice. Our pets don't have this problem — they're ambient, not modal.
The visual language (small, peripheral, non-blocking) is different.

### Shimeji (Java desktop pets)

- XML-defined behavior trees with per-animation state machines.
- Core behaviors: walk on desktop, climb screen edges, sit on windows,
  fall when windows close, multiply/clone.
- Multi-instance via independent threads with a shared position registry.
  Proximity triggers (50px) cause interactions.

### Neko (1989, the original)

- 8-direction running + sitting + scratching + yawning + sleeping.
- When it catches the cursor: stare → scratch → yawn → sleep. A micro
  narrative from a handful of sprites.
- Lesson: **sequence matters more than variety.** Five well-sequenced
  animations feel more alive than twenty randomly shuffled ones.

### Desktop Goose

- Adversarial personality (steals cursor, drags memes onto screen).
- Lesson: **personality is behavior, not appearance.** The goose is a
  simple sprite. The charm is entirely in what it *does*.

### Peon-Pet (Electron, Claude Code integration)

- 6×6 sprite atlas, event-driven state machine.
- Maps Claude Code events directly to animation states.
- Returns to sleeping after 30s of inactivity.
- Tracks up to 10 sessions with visual indicators (glowing orbs).

## v1 Analysis: What's Wrong

### Animation is robotic
- **No idle fidgets.** A sitting pet loops the same 4 frames forever.
  No blinks, no ear twitches, no glances, no yawns.
- **No transitions.** Sleep → sit is a hard frame swap. No wake-up
  stretch, no sit-to-stand, no overshoot on stopping.
- **No physics.** Constant-velocity movement. Instant start/stop.
  Straight lines only.
- **Sleep is 2 frames.** The most commonly seen state (idle sessions)
  has the least animation.

### Timing is broken
- `NSTimer` at 15 FPS, not display-linked. Jittery under load.
- `dt` is hardcoded to `1/15` instead of measured. Physics drift.
- `Date()` used for pause timing — wall clock, not monotonic.

### Visual grounding is missing
- No shadow below the pet. It floats.
- No dust or particles. Movement has no weight.
- No breathing bob when idle. Stillness reads as frozen, not calm.
- Speech bubbles snap on/off. No entrance/exit animation.

### State machine is shallow
- 7 states, no sub-states. A sitting pet has zero behavioral variety.
- No escalating idle levels. A pet that's been sitting for 2 minutes
  looks identical to one that just sat down.
- No `dragged` animation. Pet shows its current state while held.
- Alert vs bark are visually identical (same sprite row).

## v2 Architecture

### Principle: Two-Layer Animation

Separate the **behavior state machine** (what the pet is doing) from the
**animation playback** (what frames are showing). The behavior layer
decides "play the wake-up animation, then idle." The animation layer
handles frame sequencing, transitions, and overlays.

```
Behavior Layer (PetBrain)
  Decides: "session went working → play sit-down, enter idle tier 1"
  Emits: animation commands (play, queue, interrupt)

Animation Layer (PetAnimator)  
  Executes: frame stepping, transitions, overlays (blink, breathe)
  Drives: sprite frame, position offsets (bob, squash), particle spawns
```

This decoupling means the behavior layer doesn't need to know about frame
counts, and the animation layer doesn't need to know about sessions.

### Principle: Animation Queue

Borrowed from Microsoft Agent. Animations are queued, not set:

```swift
animator.play(.wakeUp)           // plays to completion
animator.queue(.idle)            // starts after wakeUp finishes
animator.interrupt(with: .alert) // plays exit frames of current, then alert
```

State changes from the session don't immediately swap the sprite. They
queue the appropriate transition animation, which plays out naturally.

### Principle: Idle Tiers

Three escalating idle levels, inspired by Clippy:

| Tier | Entry | Behavior |
|------|-------|----------|
| **Idle 1** (attentive) | 0s | Breathing + periodic blinks (3-7s). Occasional ear twitch or glance (5-15s). Pet is alert and responsive. |
| **Idle 2** (bored) | 30s | Tier 1 plus: yawning, stretching, scratching, looking around more frequently. |
| **Idle 3** (drowsy) | 120s | Tier 2 plus: head droops, eyes half-close, eventually transitions to sleeping. |

The tier resets whenever the session status changes or the user interacts.

### Principle: Measured Time

Replace `NSTimer` with `CADisplayLink` (macOS 14+) or `CVDisplayLink`.
Measure actual `dt` from `CACurrentMediaTime()`. All physics use `dt`,
no `Date()` for timing.

## Sprite Sheet: What We Need

The v1 sheet has 6 rows. For v2, we need ~12-14 rows to cover transitions
and idle variety. All sprites remain right-facing, flipped at render time.

| Row | Animation | Frames | Loop | Notes |
|-----|-----------|--------|------|-------|
| 0 | **Idle/Sit** | 4-6 | Yes | Gentle breathing cycle. Base idle state. |
| 1 | **Walk** | 6-8 | Yes | Full walk cycle with contact/passing poses. |
| 2 | **Run** | 6-8 | Yes | Faster gait, ears back, body lower. |
| 3 | **Sleep** | 4-6 | Yes | Chest rise/fall, subtle ear movement. Currently 2 frames — needs 4+. |
| 4 | **Alert** (needs input) | 4-6 | Yes | Head up, ears perked, "?" body language. |
| 5 | **Bark** (needs permission) | 4-6 | Yes | Open mouth, more urgent posture. Distinct from alert. |
| 6 | **Sit → Sleep** (lie down) | 4-6 | No | Transition: curls up from sitting. |
| 7 | **Sleep → Sit** (wake up) | 4-6 | No | Transition: stretches, stands up. |
| 8 | **Walk → Sit** (arrive) | 4-5 | No | Stops, settles down with slight overshoot. |
| 9 | **Idle fidget: yawn** | 6-8 | No | Big yawn. Tier 2 idle. |
| 10 | **Idle fidget: scratch** | 6-8 | No | Scratches ear with back leg. Tier 2 idle. |
| 11 | **Idle fidget: look around** | 4-6 | No | Turns head left, hold, right, hold, center. Tier 1 idle. |
| 12 | **Celebrate** | 6-8 | No | Happy bounce/tail wag. Played when build succeeds, task completes. |
| 13 | **Held/Dragged** | 2-4 | Yes | Surprised/dangling expression while being dragged. |

### Overlay Animations (Separate from Sprite Sheet)

These are rendered on top of the pet sprite by the animation layer:

- **Blink:** 3-frame overlay (open → half → closed → open). 150-200ms.
  Triggered every 3-7s on an independent timer. Much cheaper than a
  blink variant of every row.
- **Breath bob:** 1-2px vertical oscillation on the entire sprite.
  2500ms sinusoidal cycle. Always active (even during walk — additive).
- **Shadow:** Static dark ellipse rendered below the sprite. Scales
  slightly with bounce/jump height.
- **Dust puffs:** 2-3 small circles that fade out. On run-start,
  direction change, arrive-stop.
- **Speech bubble:** Slides up from pet head over 200ms, holds, slides
  back down. Not an instant opacity swap.
- **Zzz particles:** Float upward from sleeping pet. One every 2-3s.

## Movement Physics

Replace constant-velocity straight lines with acceleration-based movement:

```
struct PetMovement {
    maxSpeed: CGFloat        // varies by state (idle walk: 50, attention: 120)
    acceleration: CGFloat    // how fast it reaches maxSpeed (300 pt/s²)
    deceleration: CGFloat    // how fast it stops (400 pt/s²)
    turnSpeed: CGFloat       // how fast it can change direction (radians/s)
}
```

### Easing

- **Start moving:** Accelerate from 0 to maxSpeed over ~200ms.
- **Stop moving:** Decelerate from current speed to 0 over ~150ms.
  Overshoot the target by 2-4pt, ease back.
- **Change direction:** Arc toward new heading, don't snap.

### Squash and Stretch

Applied as `scaleX`/`scaleY` modifiers on the sprite:

| Event | scaleX | scaleY | Duration | Curve |
|-------|--------|--------|----------|-------|
| Landing after drag | 1.15 | 0.85 | 100ms | ease-out → bounce back |
| Jump/bounce | 0.9 | 1.1 | 80ms | ease-out |
| Direction change | 1.05 | 0.95 | 60ms | ease-out |
| Arrive at home (settle) | 1.08 | 0.92 | 120ms → settle | ease-out-back |

### Wander (Roaming)

Replace random-point straight lines with Perlin noise or smoothed random
walk. The pet should meander in gentle curves, not zigzag between waypoints.

Alternatively, use a steering-behavior approach:
1. Pick a random "desire direction" every 3-8s.
2. Smoothly rotate current heading toward desire direction.
3. Apply speed along current heading.
4. Screen edges apply a repulsion force, not a hard clamp.

## Behavior: Attention Seeking

v1: Pet runs straight to cursor and stops.

v2: **Escalating urgency.**

| Time | Behavior |
|------|----------|
| 0-10s | Pet perks up (alert animation). Looks toward cursor. Doesn't move yet. |
| 10-30s | Starts walking toward cursor at idle speed. Stops ~50px away. Occasional bark/meow bubble. |
| 30-60s | Walks faster. Gets closer (30px). More frequent bubbles. |
| 60s+ | Runs to cursor. Stops 20px away. Bounces in place. "!!" bubble. |

This gives the user time to finish what they're doing before the pet
becomes insistent. The escalation itself communicates "this has been
waiting a while."

**Drag-dismiss:** Pet remembers where it was before the chase (preChaseHome)
and walks back there when work resumes. The drag location is temporary.

## Behavior: Working State

v1: Walk to home, sit. Identical sitting animation forever.

v2: Walk to home, sit, enter idle tier system.

- **Tier 1** (0-30s): Sit idle with breathing and blinking. Pet appears
  focused. Occasional glance toward... nothing in particular. Rare
  speech bubble showing current tool activity ("editing auth.ts").
- **Tier 2** (30-120s): Pet fidgets. Yawning, scratching, stretching.
  Speech bubbles more frequent. "still coding..." "searching..."
- **Tier 3** (120s+): Pet gets drowsy. Head droops. If session is still
  working after 3+ minutes with no tool change, pet falls asleep at home
  (enters sleeping animation). Wakes on next tool event.

This means a long-running `cargo build` would show: sit → fidget → drowsy
→ sleep. A rapid edit-test cycle keeps the pet alert at tier 1.

## Behavior: Multi-Instance (Future, After Dog is Polished)

Design for it now, build it later. The key constraints:

### Identity Per Project
- Map project path → animal kind. Persist in UserDefaults.
- Same project always gets the same animal across sessions.
- User can override via context menu.

### Spatial Awareness
- Each pet has a "personal space" radius (~60px).
- If another pet enters, the lower-priority one adjusts its wander target.
- Priority: attention-seeking > idle. Among same priority, earlier spawn wins.
- **No piling up at cursor.** If two pets need attention, they approach
  from different sides and maintain spacing.

### Social Behaviors (Future)
- **Notice:** When within 100px, pets glance at each other (30% chance,
  checked every ~1s).
- **Group react:** If one pet reacts to an event (alert), nearby pets
  have 50% chance to also look that direction after a 500-1500ms delay.
- **Keep it simple.** No "playing together" animations or complex
  interactions in the first pass. Acknowledgment (look at) is enough
  to feel alive.

## File Structure (v2)

```
Pets/
  PetKind.swift              # Animal enum + personality constants
  PetState.swift             # Behavior states (idle-tiered, attention-escalated)
  PetModel.swift             # Per-pet state (spatial, behavior, lifecycle)
  PetBrain.swift             # NEW: Behavior layer. Session→state transitions,
                             #   idle tier management, attention escalation,
                             #   animation command emission.
  PetAnimator.swift          # NEW: Animation layer. Frame stepping, queue,
                             #   transitions, overlays (blink, breathe, dust).
                             #   Replaces animation parts of PetAnimationEngine.
  PetPhysics.swift           # NEW: Movement only. Acceleration, deceleration,
                             #   wander, screen clamping, collision.
                             #   Replaces movement parts of PetAnimationEngine.
  PetView.swift              # SwiftUI view + AppKit mouse handling
  PetWindow.swift            # NSPanel subclass
  PetManager.swift           # Lifecycle, timer, session binding
  SpriteSheetView.swift      # Sprite cache + frame extraction
```

The main split: `PetAnimationEngine` (403 lines doing everything) splits
into `PetBrain` (behavior decisions), `PetAnimator` (frame/visual),
and `PetPhysics` (movement). Each is testable in isolation.

## Implementation Plan

### Phase 1: Foundation (make one dog feel great)

1. **New sprite sheet.** 14-row dog sheet with transitions, fidgets,
   and held state. This is the bottleneck — everything else depends on
   having the frames to play.
2. **Animation queue + transitions.** `PetAnimator` with queue, play,
   interrupt. Wire up sit→sleep, sleep→sit, walk→sit transitions.
3. **Idle tier system.** `PetBrain` manages tier escalation with
   independent blink/fidget timers.
4. **Display-link timer.** Replace NSTimer with CVDisplayLink. Measure
   real dt.
5. **Overlay system.** Blink overlay, breathing bob, shadow ellipse.
   These three alone transform the feel.

### Phase 2: Polish (make it feel physical)

6. **Acceleration/deceleration.** Ease in/out on all movement.
7. **Squash/stretch.** On landing, arrive, direction change.
8. **Dust particles.** On run start, arrive stop.
9. **Speech bubble animation.** Slide up/down instead of opacity snap.
10. **Smooth wander.** Replace straight-line roaming with curved paths.

### Phase 3: Behavior (make it smart)

11. **Attention escalation.** The 4-stage urgency ramp.
12. **Working tier 3 → sleep.** Long-running tasks cause drowsiness.
13. **Held/dragged animation.** Dedicated sprite row while dragging.
14. **Celebrate animation.** Triggered on task completion events.

### Phase 4: Multiple Pets

15. **Identity persistence.** Project → kind mapping.
16. **Spatial awareness.** Personal space, approach-from-different-sides.
17. **Social glancing.** Pets notice each other.
18. **Add cat and hamster.** With the same 14-row sprite sheet format,
    each with different personality constants (cat is lazy, hamster is
    twitchy).

## Key Numbers

Reference values from professional pixel pets and Microsoft Agent:

| Parameter | Value | Source |
|-----------|-------|--------|
| Blink interval | 3-7s (random) | Human blink rate |
| Blink duration | 150-200ms (3 frames) | Standard pixel art |
| Breathing cycle | 2500ms sinusoid | Stardew Valley |
| Breathing displacement | 1-2px at 24pt | ~6-8% of body height |
| Idle tier 1 → 2 | 30s | Microsoft Agent |
| Idle tier 2 → 3 | 120s | Microsoft Agent |
| Fidget interval (tier 1) | 8-20s | Weighted random |
| Fidget interval (tier 2) | 5-12s | More frequent |
| Animation FPS | 8-10 for sprites, 60 for movement/physics | Standard |
| Squash amount | ±15% scale | Game feel standard |
| Squash duration | 80-120ms | Game feel standard |
| Dust particle count | 3-5 puffs | Celeste, Owlboy |
| Dust particle lifetime | 200-400ms | — |
| Walk speed | 50 pt/s | v1 value, feels right |
| Run speed | 120 pt/s | Slightly faster than v1 |
| Acceleration | 300 pt/s² | ~170ms to walk speed |
| Deceleration | 400 pt/s² | ~125ms from walk speed |
| Attention notice range | 100px | Multi-pet proximity |
| Personal space radius | 60px | Multi-pet collision |
| Speech bubble show duration | 3-5s | Long enough to read |
| Speech bubble cooldown | 45-90s | v1 value, prevents spam |

## What We're NOT Doing

Explicit non-goals to keep scope contained:

- **Window walking.** Pets walking on window title bars (Shimeji-style)
  requires accessibility APIs, window tracking, and breaks easily.
  Desktop-only is fine.
- **Sound effects.** Not in v2 scope. Visual-only.
- **Multiple animals in Phase 1.** Dog only until the animation system
  is proven.
- **Adversarial behavior.** No Desktop Goose-style cursor stealing or
  screen messing. Our pets are ambient companions, not pranksters.
- **TTS or chat.** No BonziBuddy. Speech bubbles are short text only.
- **Complex AI.** No neural nets, no behavior trees with 50 nodes.
  Weighted random + timers + escalation is enough.
- **Custom user sprites.** Not yet. Standardized sheet format first.
