# Desktop Pet Sprites - Candidate Assets

Sprites downloaded for the cctop desktop pets feature.
The plan calls for 32x32 pixel art sprite sheets with 6 animation rows:
idle/sit, walk, run, sleep, alert, special (see `docs/desktop-pets-plan.md`).

## Recommendation: Best Candidates

### PRIMARY PICK: CraftPix Street Animals (OGA-BY 3.0)
**Location:** `street-animals/craftpix/`

This is the **strongest candidate** for shipping:
- Consistent art style across all animals (dogs, cats, rats)
- Already organized as separate sprite strips per animation state
- Frame size: **48x48** per frame (close to the plan's 32x32, works great at medium size)
- Includes: Idle, Walk, Attack, Hurt, Death animations
- Two color variants each for dog, cat, rat (rat works as hamster stand-in)
- **License: OGA-BY 3.0** (attribution required - credit CraftPix.net)

Animation state mapping to plan:
| Plan State      | CraftPix Animation | Notes                        |
|-----------------|-------------------|------------------------------|
| idle / sit      | Idle (4 frames)   | Perfect                      |
| walk            | Walk (6 frames)   | Perfect                      |
| run             | Walk (faster FPS)  | Use same walk at higher FPS  |
| sleep           | Idle (slower FPS)  | Slow down idle + overlay ZZZ |
| alert / bark    | Attack (4 frames) | Barking/meowing action       |
| special         | Hurt (2 frames)   | Could spin/loop for compacting |

Animals available:
- `1 Dog/` - Brown dog (48x48 frames)
- `2 Dog 2/` - Gray/dark dog variant
- `3 Cat/` - Orange tabby cat (48x48 frames)
- `4 Cat 2/` - Gray cat variant
- `5 Rat/` - Brown rat (32x32 frames) - **usable as hamster**
- `6 Rat 2/` - Gray rat variant

### SECONDARY PICK: Dog by rmazanek (CC0)
**Location:** `dog/dog-rmazanek.png`

- Single sprite sheet, 6x6 grid, 60x38px per cell
- Animations: Bark, Walk, Run, Sit Transition, Idle Sit, Idle Stand
- **License: CC0** (public domain, no attribution needed)
- Great coverage of needed states but only covers dog

### ALTERNATIVE: Pixel Wolf by alizard (CC0)
**Location:** `wolf/`

- Separate strips: run (5f, 66x66), jump (4f), sit (4f), tail idle (2f)
- Works as a larger dog/wolf variant
- **License: CC0**

## Full Inventory

### dog/
- `dog-rmazanek.png` - 360x228px sprite sheet (6x6 grid, 60x38/cell), CC0
  - Row 0: Bark (6 frames)
  - Row 1: Walk (6 frames)
  - Row 2: Run (6 frames)
  - Row 3: Sit Transition (6 frames)
  - Row 4: Idle Sit (6 frames)
  - Row 5: Idle Stand (6 frames)
- `shepardskin/dog/` - Individual GIF animations at x1/x2/x4 sizes, CC0
  - dog_walk, dog_sit, dog_sit_bark, dog_sit_look, dog_stand_bark, dog_stand_look
  - Plus full sprite sheet GIF

### cat/
- `shepardskin/cat sprite/` - Individual GIF animations at x2/x4 sizes, CC0
  - catwalk, catrun, catsprites (original sheet)
- `cat-idle-shangri-la.png` - 64x48px idle sprite sheet, CC0

### wolf/
- `wolf_run.png` - 330x66 (5 frames x 66x66), CC0
- `wolf_jump.png` - 264x66 (4 frames x 66x66), CC0
- `wolf_sit.png` - 264x66 (4 frames x 66x66), CC0
- `wolf_tail.png` - 132x66 (2 frames x 66x66), CC0

### street-animals/craftpix/
- `1 Dog/` - Idle(4f), Walk(6f), Attack(4f), Hurt(2f), Death(4f) @ 48x48, OGA-BY 3.0
- `2 Dog 2/` - Same animations, different color variant
- `3 Cat/` - Same animations @ 48x48
- `4 Cat 2/` - Same animations, different color variant
- `5 Rat/` - Idle(4f), Walk(4f), Hurt(2f), Death(4f) @ 32x32
- `6 Rat 2/` - Same, different color
- `7 Bird/`, `8 Bird 2/` - bonus bird sprites

### tiny-creatures/extracted/
- `Tilemap/tilemap.png` - 170x306px tilemap with 180 creatures at 16x16
- `Tiles/` - Individual 16x16 PNGs for each creature
- Includes dog, cat, rabbit, squirrel, and many more
- **License: CC0**
- Note: These are static (no animation frames), but could serve as
  fallback icons or inspiration. Very small at 16x16.

## License Summary

| Asset | License | Attribution Required |
|-------|---------|---------------------|
| CraftPix Street Animals | OGA-BY 3.0 | Yes - credit CraftPix.net |
| Dog (rmazanek) | CC0 | No |
| Dog (Shepardskin) | CC0 | No (appreciated) |
| Cat (Shepardskin) | CC0 | No (appreciated) |
| Cat idle (shangri-la) | CC0 | No |
| Pixel Wolf (alizard) | CC0 | No |
| Tiny Creatures (Clint Bellanger) | CC0 | No (appreciated) |

## Integration Notes

For the plan's sprite sheet format (rows = states, columns = frames):
1. The CraftPix sprites are already in horizontal strips - they just need to be
   stacked vertically into a single sheet per animal
2. The rmazanek dog is already in the exact format needed (6x6 grid)
3. For hamster: the CraftPix rat at 32x32 is the closest match. Could be
   recolored to look more hamster-like (rounder, brown/orange)
4. Missing animations (sleep, special/spin) will need to be created or
   approximated by slowing down existing idle animations

## Source URLs

- https://opengameart.org/content/dog-3 (rmazanek dog)
- https://opengameart.org/content/dog-sprites (Shepardskin dog)
- https://opengameart.org/content/cat-sprites (Shepardskin cat)
- https://opengameart.org/content/a-cat (shangri-la cat)
- https://opengameart.org/content/pixel-wolf (alizard wolf)
- https://opengameart.org/content/street-animal-pixel-art (CraftPix)
- https://opengameart.org/content/tiny-creatures (Clint Bellanger)
