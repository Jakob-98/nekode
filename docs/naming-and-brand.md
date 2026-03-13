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

## Naming Options

### Tier 1: Strong candidates

| Name | Vibe | Notes |
|---|---|---|
| **Pochi** | Cute, distinctive, ownable | Already the internal mascot name. Japanese origin (common pet name). Short, memorable, globally pronounceable. `pochi.dev` or `getpochi.app` likely available. Works as both app name and CLI (`pochi wait`, `pochi hook`). Risk: obscure, no immediate meaning to English speakers. |
| **Petcode** | Developer, clear | Combines the two core concepts. `petcode.dev` plausible. Clean for CLI (`petcode wait`). Risks feeling generic. |
| **Critters** | Playful, plural | Implies multiple animals/species from day one. Casual tone. Good for CLI (`critters wait`). Common English word — domain availability may be hard. |
| **Sidekick** | Functional, warm | Describes the role, not the form. Works if you move beyond animals entirely (robots, sprites, etc.). But overused in tech — many apps called Sidekick. |
| **Neko** | Retro, developer-nostalgic | Direct reference to [Neko (1989)](https://en.wikipedia.org/wiki/Neko_(software)), the original desktop pet. Developers over 30 will recognize it. But it means "cat" in Japanese — same species-lock problem. |

### Tier 2: Worth considering

| Name | Vibe | Notes |
|---|---|---|
| **Watchpet** | Descriptive | "Watch" = monitoring + "pet" = mascot. Clear but not exciting. |
| **Pixelpet** | Retro, literal | Describes the art style. Fun but limits you if you go 3D later. |
| **Buddy** | Warm, generic | Clippy's friendlier cousin. Too generic for search/discoverability. |
| **AgentPet** | Technical, niche | Only makes sense to AI agent users. Excludes the `catwait` audience. |
| **Kompanion** | Playful misspelling | The K gives it character. But misspellings are a UX tax — people will search for "Companion" and not find you. |
| **Deskpet** | Literal | Desktop + pet. Clear, forgettable. |

### Tier 3: Creative/risky

| Name | Vibe | Notes |
|---|---|---|
| **Shimeji** | Developer-nostalgic | Famous desktop pet app. But it's an existing active project — too close. |
| **Tamagotchi** | Nostalgic | Trademarked. Cannot use. |
| **Clippy** | Maximum nostalgia | See analysis below. |

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

## Recommendations

**Name:** Go with **Pochi** if you want something ownable and distinctive, or **Critters** if you want something immediately understood. Pochi is the bolder choice — it's unique, short, works great as a CLI name, and you already use it internally. The obscurity is a feature: it's a blank canvas that means whatever you make it mean.

**Theme:** Direction A (keep cats, expand species later) with elements of C (lean into pixel-art nostalgia). The pixel-art desktop pet is your moat — no other developer tool has this. Don't dilute it by going "clean and minimal."

**Clippy:** Reference it in marketing, never in the product name. Use the *concept* (ambient desktop companion that reacts to your work) without the *brand*.

**Tagline candidates:**
- "Desktop pets for your coding agents" (clear, descriptive)
- "Your agents are working. Your pets are watching." (personality)
- "See all your AI sessions. Pet included." (casual, intriguing)
- "Know when your agents need you — without watching them." (functional)
- "The desktop pets your terminal deserves." (catwait-first angle)

**CLI naming (if Pochi):**
- `pochi` (main app)
- `pochi wait` or `pochiwait` (replaces `catwait`)
- `pochi hook` or `pochihook` (replaces `cathook`)

**CLI naming (if Critters):**
- `critters` (main app)
- `critters wait` or `crwait` (replaces `catwait`)
- Hook binary stays internal

**Next steps:**
1. Pick a name
2. Check domain availability (`{name}.dev`, `{name}.app`, `get{name}.com`)
3. Check npm/brew/GitHub availability
4. Rename repo, bundle ID, CLI binaries
5. Create Homebrew tap under new name
6. Ship first Homebrew release
7. Add first non-cat species as a post-launch update
