# Naming & Brand Direction

## What We Built

A macOS menubar app that monitors AI coding sessions — Claude Code, GitHub Copilot, opencode, and arbitrary CLI commands via `catwait`. One floating panel shows all active sessions with color-coded status. Click to jump to any session's terminal window. Keyboard-native (arrows, Enter, Tab, hotkeys).

The distinctive feature: **desktop pets**. Pixel-art animals that live on your screen, one per active session. They mirror session state in real time — sleeping when idle, walking when working, chasing your cursor when something needs your attention. A 4-tier idle system inspired by Clippy's animation engine (without the unsolicited advice). 18 animation states. Squash-and-stretch physics, dust particles, speech bubbles showing what the agent is doing ("editing auth.ts", "searching...").

There's also `catwait` — pipe any command and get a live session + desktop pet that tells you when it's done. This is the broader hook: it works for any developer, not just AI agent users.

**Current identity:** "CatAssistant" with a single cat character called "Pochi" in 6 color variants. Teal brand color. MIT licensed, Homebrew distribution planned, $9.99 one-time license considered.

**Current positioning:** "Your AI agents are working. You shouldn't have to watch them."

---

## Why Rename

"CatAssistant" made sense when the app was a cat-themed Claude Code monitor. But:

- The product now supports 4+ tools (Claude Code, Copilot, opencode, CLI)
- The most marketable feature is desktop pets, not the menubar panel
- "Cat" in the name locks us into one animal species
- The `catwait` CLI branding is confusing — "cat" collides with the Unix `cat` command
- If we add dogs, hamsters, robots, or custom pets, the name actively misleads

A rename now (before Homebrew tap, before any real distribution) is essentially free. After distribution it becomes expensive.

---

## Chosen Name: Nekode

See the full analysis in the [Decision: Nekode](#decision-nekode) section below.

**Nekode** = Neko (desktop pet heritage) + Code (developer tool). Both halves instantly recognizable. Doesn't lock into cats. Works as CLI. Unique and ownable.

---

## The Clippy Question

**Can you use "Clippy" in your marketing?**

Short answer: risky, and probably not worth it.

- **Trademark:** Microsoft has active trademarks on "Clippy" and "Clippit" (the character's actual name). The character design is copyrighted.
- **Referencing Clippy in marketing copy** ("like Clippy, but for AI agents") is generally fine — that's nominative fair use. You're describing a concept, not claiming the brand.
- **Using "Clippy" in the product name** (e.g., "Clippy.ai", "ClippyCode") is risky. Microsoft has enforced this — they sent takedowns to projects using the Clippy name/likeness.
- **Using a paperclip character** is a gray area. The generic paperclip isn't owned by Microsoft, but a helpful animated paperclip with eyes is close enough to invite trouble.

**Recommendation:** Reference Clippy in marketing copy and blog posts ("Clippy-style desktop pets for your AI coding sessions"), never in the product name, app icon, or character design. The nostalgia value comes from the concept (ambient desktop companion that reacts to what you're doing), not from the specific brand.

A tagline like "Remember Clippy? This is what it should have been." works. A product name like "ClippyCode" does not.

---

## Theme Directions

### A. Keep cats, expand species

Stay with pixel-art animals but add variety: dogs, hamsters, birds, rabbits, foxes. Users pick their preferred animal or get one assigned per session. The "Pochi" cat becomes the default/flagship.

**Pros:** You already have 18 animation states and 6 color variants for cats. Adding species is additive — the existing work isn't wasted. Animals are universally appealing. Each new species is a marketing moment ("Dogs are here!").

**Cons:** Every new animal needs its own sprite sheet (16 columns x N rows x 64px cells). That's significant pixel art work per species. The 3D pipeline (Tripo → Mixamo → USDZ) could solve this but isn't built yet.

**Best names for this direction:** Critters, Pochi (flagship mascot + friends), Petcode, Deskpet.

### B. Clippy-inspired assistant aesthetic

Lean into the "helpful desk companion" angle. Single character (or small roster) with personality. Think: a pixel-art assistant that lives on your screen, shows you what your agents are doing, and only bothers you when something needs attention. More character-driven, less zoo.

**Pros:** Strongest narrative hook. "Clippy but actually good" is an instant pitch. The tiered idle system and attention escalation already support this — it's what the product does. One character to market, one character to perfect.

**Cons:** "Single character" limits the visual variety that makes multi-session monitoring legible at a glance. You'd need to differentiate sessions through color, accessories, or position rather than species. Also, leaning too hard into "Clippy" comparisons invites the "but Clippy was annoying" reaction.

**Best names for this direction:** Sidekick, Buddy, Pochi (as the one character).

### C. Retro/pixel-art nostalgia

Full commitment to the pixel-art desktop pet genre. Position as the spiritual successor to Neko (1989), Shimeji, eSheep, and the Tamagotchi era. Pixel-art is the identity, not just the implementation.

**Pros:** Strong aesthetic differentiation in a market of clean/minimal developer tools. Nostalgia is powerful marketing — "desktop pets are back" is a compelling hook. The existing art style already supports this.

**Cons:** Locks you into pixel art. The 3D pets direction (SceneKit/USDZ) becomes a brand contradiction. May feel unserious to some developers — though the "unserious tool that's actually useful" is a proven archetype (see: Warp terminal, Fig).

**Best names for this direction:** Neko, Pixelpet, Critters, Pochi.

### D. Clean developer tool with personality

The pets are a delightful feature, not the entire brand. The product is a session monitor; the pets are the thing that makes people remember it and share screenshots. Think: Linear (clean dev tool) but with a mascot.

**Pros:** Broadest market. Doesn't scare off developers who think desktop pets are silly. The menubar panel is genuinely useful without pets. Easier to charge $9.99 for a "developer tool" than for "desktop pets."

**Cons:** Less distinctive. "Another menubar app" is harder to market than "desktop pets for your AI agents." You lose the virality angle — nobody screenshots a menubar panel.

**Best names for this direction:** Sidekick, Petcode, Watchpet.

---

## Should You Add New Animals Now?

**No.** Not before the rename and distribution are settled.

Reasons:
1. Each animal needs a full sprite sheet (18 states, 16 frames each, 64x64px). That's ~288 hand-drawn frames per species. This is the bottleneck — not code.
2. The Pochi cat with 6 color variants already handles up to 6 concurrent sessions distinctly. Most users won't have more than 3-4 simultaneous AI sessions.
3. New animals are a great post-launch marketing event. Save them for after initial adoption. "Dogs just dropped" is a tweet that gets engagement.
4. If you go the 3D pipeline route (Tripo → Mixamo → USDZ), adding animals becomes trivially cheap. Worth waiting to see if that pans out before commissioning more pixel art.

**What to do instead:** Ship with cats (Pochi), get the Homebrew tap live, get real users. Add the first non-cat animal (probably a dog) as a v1.1 update once you know people care.

---

## Decision: Nekode

**Nekode** = Neko (cat / desktop pet heritage, 1989) + Code (developer tool)

### Why this wins

- Both halves are instantly recognizable to developers
- References the original desktop pet lineage without using a trademarked name
- Doesn't lock into cats — "neko" is the heritage, not the constraint. Dogs and hamsters under the Nekode brand feel natural
- Short (3 syllables), unique, globally pronounceable
- Natural English reading is "neh-code" which lands perfectly
- Works as a CLI name: `nekode wait`, `nekode hook`
- Sounds like it could be a real word (echoes "decode", "node", "mode")

### Domain strategy

- `nekode.dev` — best option (check availability). `.dev` is the natural home for developer tools
- `nekode.app` — second choice, Apple/macOS association
- `getnekode.com` — fallback using the proven `get` prefix pattern
- `.net` and `.org` are available but skip them — they signal "taken" not "developer tool"

### CLI naming

| Current | Nekode |
|---|---|
| CatAssistant.app | Nekode.app |
| `cathook` | `nekode hook` or `nekohook` |
| `catwait` | `nekode wait` or `nekowait` |
| `~/.cat/sessions/` | `~/.nekode/sessions/` |
| `com.jakobserlier.CatAssistant` | `dev.nekode.app` (or `com.nekode.app`) |
| `jakobserlier/catassistant` | `jakobserlier/nekode` (or `nekode/nekode`) |
| `jakobserlier/homebrew-catassistant` | `jakobserlier/homebrew-nekode` |
| `brew install --cask catassistant` | `brew install --cask nekode` |

### Rename scope

Full list of what needs updating (do NOT do yet — do after domain is secured):

**Code & config:**
- Xcode project: target names, bundle identifier, product names
- `Info.plist`: app name, Sparkle feed URL
- `scripts/bump-version.sh`: all 7+ version locations need path updates
- `scripts/bundle-macos.sh`: output names, paths
- `scripts/sign-and-notarize.sh`: bundle references
- `scripts/create-dmg.sh`: DMG naming
- `scripts/generate-appcast.sh`: URLs, paths
- `Makefile`: build paths, install paths
- `packaging/homebrew-cask.rb`: cask name, URLs, paths
- `appcast.xml`: feed URLs

**CLI binaries:**
- `cathook` target → `nekohook` (or keep as single `nekode` binary with subcommands)
- `catwait` target → `nekowait` (or `nekode wait`)
- `~/.cat/` → `~/.nekode/` (session data directory)
- All plugins that reference `~/.cat/` or `cathook`

**Plugins:**
- `plugins/catassistant/` → `plugins/nekode/`
- `plugins/opencode/opencode-plugin.js`: session path references
- `plugins/copilot/`: hook paths
- `.claude-plugin/`: plugin name, marketplace metadata

**GitHub:**
- Rename repo `catassistant` → `nekode`
- Create `homebrew-nekode` tap repo (instead of `homebrew-catassistant`)
- Update all workflow URLs

**Marketing/docs:**
- `README.md`
- `docs/release-checklist.md`
- `docs/distribution.md`
- Landing page / product page copy
- Appcast feed URL in Info.plist

### Tagline candidates

- "Desktop pets for your coding agents"
- "Your agents are working. Your pets are watching."
- "See all your AI sessions. Pet included."
- "The desktop pets your terminal deserves."
- "Remember Clippy? This is what it should have been." (for marketing copy, not tagline)

### What stays the same

- **Pochi** remains the flagship mascot name (the cat character). Nekode is the product, Pochi is the pet.
- Teal brand color
- Pixel-art aesthetic
- All animation/behavior code — no functional changes
- MIT license model
- Monetization plan ($9.99 one-time)

---

## Previous Candidates (for reference)

**Tier 1:**

| Name | Vibe | Notes |
|---|---|---|
| **Pochi** | Cute, distinctive, ownable | Already the internal mascot name. Japanese origin. Short, memorable. Risk: obscure to English speakers. |
| **Petcode** | Developer, clear | Combines the two core concepts. Risks feeling generic. |
| **Critters** | Playful, plural | Implies multi-species from day one. Domain availability likely hard. |
| **Sidekick** | Functional, warm | Works beyond animals. Overused in tech. |
| **Neko** | Retro, nostalgic | References the 1989 desktop pet. Still means "cat" — same species-lock. |

**Tier 2:** Watchpet, Pixelpet, Buddy, AgentPet, Kompanion, Deskpet — all considered and rejected for various reasons (generic, limiting, or hard to discover).

---

## Theme & Species Strategy

**Theme:** Direction A (pixel-art animals, expand species over time) with nostalgia elements. The pixel-art desktop pet is the moat. Nekode's name carries the retro heritage; the product itself leans into it.

**Clippy:** Reference in marketing copy ("Clippy-style desktop pets for AI coding sessions"), never in the product name. Microsoft actively enforces the trademark.

**Species timeline:**
1. **Launch:** Pochi cat (6 color variants, 18 animation states) — already built
2. **v1.1:** First non-cat species (dog) — marketing moment ("Dogs just dropped")
3. **Later:** More species as demand/art pipeline allows. Consider 3D pipeline (Tripo → Mixamo → USDZ) to eliminate per-species sprite art bottleneck

**Don't add new animals before launch.** Each species needs ~288 hand-drawn frames. Pochi's 6 color variants handle 6 concurrent sessions. New species are better as post-launch marketing events.

---

## Next Steps

1. Secure domain (`nekode.dev` preferred, then `nekode.app`, then `getnekode.com`)
2. Check GitHub org/username availability for `nekode`
3. Rename GitHub repo
4. Execute the full rename (see scope above)
5. Create `homebrew-nekode` tap repo
6. Ship first Homebrew release
7. Add first non-cat species post-launch
