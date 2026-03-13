# AGENTS.md

macOS menubar app (CatAssistant) that monitors coding sessions from Claude Code, opencode, vscode (in development), and arbitrary CLI commands. Shows session status in the menubar and as desktop pets — pixel-art animals that mirror each session's state. Includes `cathook` (shell hook for session tracking) and `catwait` (pipe-based CLI for monitoring any command).

Build: `make build` / `make install` / `make run`

regarding testing. I'd rather have fewer tests which are clear, than a large sum of tests for arbitrary small behavior features.


## WORKLIST

keep track of all work ongoing/done work. ONE LINE per complex task. You MAY add very brief links to important files etc under a line. ADD MAJOR TODOS only, or blockers, etc. Update often. Keep latest state there.

format: - dd-mm-yyyy: S: ONGOING/DONE/[...] -  

- (next agent: feel free to add current date, and todo) - add oneliner install  | sh option both to frontend and a script as part of the public repository, following the brew plan described in docs/distribution.md
- 10-03-2026: S: DONE. VS Code Copilot integration (hooks, install UI, detection, hook format, JSONC settings). See `docs/copilot-integration.md`
- 10-03-2026: S: DONE. Per-source pet toggle (CC/CP/OC/CLI) via UserDefaults. `PetManager.swift`, `SettingsSection.swift`
- 10-03-2026: S: DONE. Copilot Stop→waitingInput fix (Copilot has no Notification hook). `HookEvent.swift`
- 10-03-2026: S: DONE. Stale Copilot session cleanup — 5min inactivity timeout in `Session.isAlive`. `Session.swift:300`
- 13-03-2026: S: DONE. Pet window click-through fix — hitTest-only approach (`ignoresMouseEvents=false`, `hitTest` returns nil outside sprite+nametag rect), `canBecomeKey=false`, `.ignoresCycle`. Removed broken NSTrackingArea approach. `PetWindow.swift`, `PetView.swift`
- 13-03-2026: S: DONE. Sleep wake-on-drag + sleep blink animations. `PetModel.swift`, `PetAnimationEngine.swift`
- 10-03-2025: S: TODO. refactor icons. Low prio
- 13-03-2026: S: DONE. Multi-cat anti-glitch: soft velocity-based repulsion, gentler collision (30% correction), dynamic vibe zone sizing, sleep drift avoids neighbors, Y-based z-ordering. `PetAnimationEngine.swift`, `PetManager.swift`, `PetWindow.swift`
- 13-03-2026: S: DONE. Fix "flying" pet bug — micro-velocity from neighbor avoidance kept pets in walking sprite (1.0 scale). Added speed threshold (2pt/s) in `visualState` + velocity snap-to-zero in tick. `PetModel.swift:244`, `PetAnimationEngine.swift:157`
- 13-03-2026: S: DONE. Fix pet collision oscillation — stationary pets accept collision pushes instead of walking back (wider tolerance zone), targets near neighbors get repicked, vibe zone enlarged (280x160 base, +100w/+50h per extra pet), hitbox +5% and shifted down. `PetAnimationEngine.swift`, `PetManager.swift`, `PetWindow.swift`
- 13-03-2026: S: DONE. Principal engineer review cleanup — double-click bug fix (`PetMouseView` `didDoubleClick` flag), hitbox increased (0.85), vibe zone tuned (200x120 base), magic numbers extracted to `PetPhysics`, velocity==.zero exact equality replaced with threshold checks, `isMoving`/`isAttentionSeeking` merged in `PetState`. `PetView.swift`, `PetAnimationEngine.swift`, `PetModel.swift`, `PetWindow.swift`, `PetManager.swift`, `PetState.swift`
- 13-03-2026: S: DONE. Dead code removal — `updateRoaming()`, `gatheringTarget()`, `edgeRepulsionHeading()`, `normalizeAngle()` + roam heading properties + 4 dead tests. Consolidated duplicate attention reset blocks in `updateStateTransition`. `PetAnimationEngine.swift`, `PetModel.swift`, `PetTests.swift`
- 13-03-2026: S: NOT A BUG. Name tag "disappearing when working" — intentional opacity=0 when not hovering and not needsAttention. Text content never cleared.
