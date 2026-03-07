# 3D Pets

Replace sprite sheet rendering with real-time 3D models via SceneKit. One model per pet kind, with animations for each state — eliminates the need for hand-drawn sprite frames and makes adding new pets/states trivial.

## Pipeline

1. **Model** — Export from Tripo3D as GLB/FBX
2. **Rig + Animate** — Run through Mixamo for auto-rigging and stock animations (idle, walk, run, sleep), or rig manually in Blender for non-humanoid shapes
3. **Convert** — GLB → USDZ via Apple's Reality Converter or `usdzconvert`
4. **Render** — `SCNView` wrapped in `NSViewRepresentable`, replacing `SpriteSheetView`. Orthographic camera, toon/flat shading to stay readable at small sizes

## Architecture change

```
Current:  PetState → spriteRow + frame → SpriteSheetCache → NSImage → Image
Proposed: PetState → animation name → SCNScene → SCNView
```

- `SpriteSheetView` → `PetSceneView` (SceneKit)
- `PetKind.spriteSheetName` → `PetKind.modelFileName` (USDZ in asset catalog)
- `PetState.spriteRow` → `PetState.animationName` (`"idle"`, `"walk"`, `"run"`, etc.)
- Frame counting goes away — SceneKit handles animation playback and looping natively
- Animation blending enables personality (blend idle into walk for a "lazy" variant)

## Open questions

- Does the Tripo model have a skeleton, or does it need rigging?
- Performance with multiple `SCNView` windows — fine for 1-3 pets, needs profiling beyond that
- Art direction: toon shader vs. realistic lighting at 48-64pt on-screen size
