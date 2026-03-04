#!/usr/bin/env python3
"""
Composite CraftPix sprite strips into unified sprite sheets for cctop desktop pets.

Layout per sheet (rows = animation states, columns = frames):
  Row 0: Idle/Sit     — from Idle strip
  Row 1: Walk         — from Walk strip
  Row 2: Run          — duplicate of Walk (rendered at higher FPS in engine)
  Row 3: Sleep        — first 2 frames of Idle (rendered at slow FPS in engine)
  Row 4: Alert/Bark   — from Attack strip (dog/cat) or derived from Idle (hamster)
  Row 5: Special/Spin — from Death strip reversed (spin-like loop)

Outputs @2x PNGs (native CraftPix size: 48x48 for dog/cat, 32x32 for rat).
Also outputs @1x PNGs at half size (24x24 for dog/cat, 16x16 for rat).

Then scales all to a uniform 48x48 @2x / 24x24 @1x base so the engine
can use a single frame size per animal. (Rat sprites are upscaled from 32 to 48.)
"""

import os
from PIL import Image

BASE = os.path.dirname(os.path.abspath(__file__))
CRAFTPIX = os.path.join(BASE, "street-animals", "craftpix")
OUTPUT = os.path.join(BASE, "output")
os.makedirs(OUTPUT, exist_ok=True)

# Target: 6 rows, up to 6 columns, 48x48 per cell @2x
TARGET_CELL_2X = 48
TARGET_CELL_1X = 24
MAX_COLS = 6
NUM_ROWS = 6


def load_strip(path):
    """Load a horizontal sprite strip and return list of frame Images."""
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    frame_w = h  # Frames are square (48x48 or 32x32)
    num_frames = w // frame_w
    frames = []
    for i in range(num_frames):
        frame = img.crop((i * frame_w, 0, (i + 1) * frame_w, frame_w))
        frames.append(frame)
    return frames


def derive_sleep(idle_frames):
    """Sleep = first 2 frames of idle (engine plays at slow FPS)."""
    return idle_frames[:2]


def derive_special(death_frames):
    """
    Special/spin = death frames reversed to create a looping spin effect.
    Take frames and reverse to make it loop: [0,1,2,3] -> [0,1,2,3,2,1]
    But keep max 6 frames: just use the first 4 frames reversed as [3,2,1,0].
    Actually, let's use a forward+backward loop: [0,1,2,1] for 4 frames.
    """
    if len(death_frames) >= 4:
        return [death_frames[0], death_frames[1], death_frames[2], death_frames[1]]
    return death_frames[:4]


def derive_alert_from_idle(idle_frames):
    """For hamster (rat has no Attack), derive alert from idle frames with a shift."""
    # Use idle frames but in a different order to suggest alertness: [0,1,0,2] or similar
    if len(idle_frames) >= 4:
        return [idle_frames[0], idle_frames[1], idle_frames[2], idle_frames[3]]
    return idle_frames


def compose_sheet(animal_dir, animal_name, has_attack=True):
    """Compose a unified sprite sheet for one animal."""
    print(f"\nComposing {animal_name} from {animal_dir}")

    idle_frames = load_strip(os.path.join(animal_dir, "Idle.png"))
    walk_frames = load_strip(os.path.join(animal_dir, "Walk.png"))
    death_frames = load_strip(os.path.join(animal_dir, "Death.png"))
    hurt_frames = load_strip(os.path.join(animal_dir, "Hurt.png"))

    if has_attack:
        attack_frames = load_strip(os.path.join(animal_dir, "Attack.png"))
    else:
        attack_frames = None

    # Build rows
    rows = [
        idle_frames,                                      # Row 0: Idle/Sit
        walk_frames,                                      # Row 1: Walk
        walk_frames,                                      # Row 2: Run (same frames, faster FPS)
        derive_sleep(idle_frames),                        # Row 3: Sleep
        attack_frames if attack_frames else derive_alert_from_idle(idle_frames),  # Row 4: Alert
        derive_special(death_frames),                     # Row 5: Special
    ]

    # Determine native cell size from first frame
    native_cell = idle_frames[0].size[0]
    print(f"  Native cell size: {native_cell}x{native_cell}")

    # Frame counts per row
    frame_counts = [len(row) for row in rows]
    max_cols = max(frame_counts)
    print(f"  Frame counts per row: {frame_counts}")
    print(f"  Max columns: {max_cols}")

    # Compose at native resolution (@2x target)
    sheet_w = max_cols * native_cell
    sheet_h = NUM_ROWS * native_cell
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    for row_idx, frames in enumerate(rows):
        for col_idx, frame in enumerate(frames):
            x = col_idx * native_cell
            y = row_idx * native_cell
            sheet.paste(frame, (x, y))

    # Scale to uniform TARGET_CELL_2X if needed
    if native_cell != TARGET_CELL_2X:
        new_w = max_cols * TARGET_CELL_2X
        new_h = NUM_ROWS * TARGET_CELL_2X
        print(f"  Scaling from {native_cell} to {TARGET_CELL_2X} per cell")
        sheet_2x = sheet.resize((new_w, new_h), Image.NEAREST)
    else:
        sheet_2x = sheet

    # Save @2x
    path_2x = os.path.join(OUTPUT, f"{animal_name}-sprites@2x.png")
    sheet_2x.save(path_2x)
    print(f"  Saved @2x: {path_2x} ({sheet_2x.size[0]}x{sheet_2x.size[1]})")

    # Generate @1x (half size)
    w1x = sheet_2x.size[0] // 2
    h1x = sheet_2x.size[1] // 2
    sheet_1x = sheet_2x.resize((w1x, h1x), Image.NEAREST)
    path_1x = os.path.join(OUTPUT, f"{animal_name}-sprites.png")
    sheet_1x.save(path_1x)
    print(f"  Saved @1x: {path_1x} ({w1x}x{h1x})")

    return frame_counts, max_cols


def main():
    print("=== Compositing CraftPix sprites into unified sprite sheets ===")

    results = {}

    # Dog (variant 1 - brown)
    dog_dir = os.path.join(CRAFTPIX, "1 Dog")
    results["dog"] = compose_sheet(dog_dir, "dog", has_attack=True)

    # Cat (variant 3 - orange tabby)
    cat_dir = os.path.join(CRAFTPIX, "3 Cat")
    results["cat"] = compose_sheet(cat_dir, "cat", has_attack=True)

    # Hamster (rat variant 5 - brown, used as hamster proxy)
    rat_dir = os.path.join(CRAFTPIX, "5 Rat")
    results["hamster"] = compose_sheet(rat_dir, "hamster", has_attack=False)

    print("\n=== Summary ===")
    print(f"Output directory: {OUTPUT}")
    for name, (frame_counts, max_cols) in results.items():
        print(f"  {name}: {NUM_ROWS} rows x {max_cols} max cols, "
              f"frames per row: {frame_counts}")

    # Print the frame count data needed for Swift code
    print("\n=== Swift PetState.frameCount values ===")
    state_names = ["idle/sit", "walk", "run", "sleep", "alert", "special"]
    for name, (frame_counts, _) in results.items():
        print(f"  {name}:")
        for i, state in enumerate(state_names):
            print(f"    {state}: {frame_counts[i]} frames")


if __name__ == "__main__":
    main()
