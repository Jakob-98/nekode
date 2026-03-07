# Sprite Art Requirements

Desktop pets for a macOS menubar app. Small pixel-art animals (dog, cat, hamster) that live on screen and reflect the state of AI coding sessions. Each animal needs a single **sprite sheet PNG** — a grid of 48x48px cells on a transparent background. Dog and cat sheets are **6 columns wide**, hamster is **4 columns wide**. All sprites face **right** (left-facing is handled by flipping at render time). We need both a @2x version (48px cells) and a @1x version (24px cells) for each animal. Style should be warm, chunky pixel art — think Stardew Valley pets, not hyper-detailed.

## Rows

Each row is one animation state. Frames play left-to-right, looping.

| Row | State | Frames | Description |
|-----|-------|--------|-------------|
| 0 | **Sitting (idle)** | 4–6 | Relaxed sitting with subtle life — ear flicks, tail wags, head tilts, stretching, yawning. This is the most-seen state, so variety matters. Not a static loop. |
| 1 | **Walking** | 4–6 | Gentle trot cycle. Legs move, body bobs slightly. |
| 2 | **Running** | 4–6 | Faster gallop/sprint. More exaggerated leg extension. |
| 3 | **Sleeping** | 2 | Curled up or lying down with a slow breathing rise/fall. Minimal movement. |
| 4 | **Alert / Barking** | 4 | Upright, ears perked, mouth open. For dog: barking. For cat: meowing/hissing. For hamster: standing on hind legs, squeaking. |
| 5 | **Spinning** | 4 | Chasing own tail or rolling. Full 360° rotation over the 4 frames. |

## Sizes (current)

| Animal | Columns | Sheet @2x | Sheet @1x |
|--------|---------|-----------|-----------|
| Dog | 6 | 288 x 288 px | 144 x 144 px |
| Cat | 6 | 288 x 288 px | 144 x 144 px |
| Hamster | 4 | 192 x 288 px | 96 x 144 px |

## Notes

- The hamster should read clearly as a hamster (round body, small ears, stubby legs) — the current version looks too much like a rat (long body, pointy snout).
- Idle (row 0) is the hero animation. The pet sits here while the AI agent is working, which can be minutes. It needs enough visual variety across its frames that it doesn't feel like a GIF on repeat.
- Transparent background, no drop shadow (shadow is rendered separately in code).
- Palette: warm and friendly. Dog is dark blue/navy with orange accents. Cat is orange tabby. Hamster is brown/tan. Open to variations as long as they read well at 48px.
