import Foundation

/// Defines the layout of a Pochi sprite sheet row:
/// which row it occupies, how many frames it has, and any special handling.
struct SpriteRowConfig {
    /// Row index in the sprite sheet (0-based, top to bottom).
    let row: Int
    /// Number of usable animation frames in this row.
    let frames: Int
    /// Columns to skip (0-indexed). E.g. row 17 skips column 6 (the red flash).
    let skipColumns: Set<Int>
    /// Whether the animation loops continuously or plays once and holds.
    let loops: Bool
    /// Human-readable label for debugging / config display.
    let label: String

    init(
        row: Int, frames: Int, label: String,
        skipColumns: Set<Int> = [], loops: Bool = true
    ) {
        self.row = row
        self.frames = frames
        self.label = label
        self.skipColumns = skipColumns
        self.loops = loops
    }
}

// MARK: - Pochi Sprite Grid

/// Central mapping of Pochi sprite sheet rows → animation metadata.
///
/// This is the single source of truth for row indices, frame counts,
/// skipped frames, and loop behavior. PetState reads from this config
/// instead of hardcoding values in switch statements.
///
/// Pochi grid: 1024×1216 px, 64px cells, 16 cols × 19 rows.
enum PochiSpriteGrid {

    /// All row definitions, keyed by the PetState raw name.
    /// Order matches the sprite sheet (row 0 at top).
    static let rows: [String: SpriteRowConfig] = {
        var map: [String: SpriteRowConfig] = [:]
        for entry in allRows {
            map[entry.key] = entry.config
        }
        return map
    }()

    /// Ordered list for iteration / debugging.
    static let allRows: [(key: String, config: SpriteRowConfig)] = [
        ("sitting",      SpriteRowConfig(row: 0,  frames: 6,  label: "Sitting idle (tail swish)")),
        ("standing",     SpriteRowConfig(row: 1,  frames: 3,  label: "Standing idle / attentive")),
        ("flopped",      SpriteRowConfig(row: 2,  frames: 1,  label: "Flop onto side", loops: false)),
        ("sleeping",     SpriteRowConfig(row: 3,  frames: 4,  label: "Sleeping (curled)")),
        ("sneaking",     SpriteRowConfig(row: 4,  frames: 8,  label: "Low crawl / sneaking")),
        ("walking",      SpriteRowConfig(row: 5,  frames: 6,  label: "Walking cycle")),
        ("running",      SpriteRowConfig(row: 6,  frames: 10, label: "Faster run")),
        ("boxIdle",      SpriteRowConfig(row: 7,  frames: 12, label: "Sitting in box (idle)", loops: false)),
        ("boxWiggle",    SpriteRowConfig(row: 8,  frames: 10, label: "Box wiggle / playful shake")),
        ("boxPeek",      SpriteRowConfig(row: 9,  frames: 12, label: "Box peek / pop up")),
        ("crying",       SpriteRowConfig(row: 10, frames: 4,  label: "Crying / sad")),
        ("dancing",      SpriteRowConfig(row: 11, frames: 4,  label: "Happy dance / excited jump")),
        ("lookingUp",    SpriteRowConfig(row: 12, frames: 8,  label: "Sitting and looking up")),
        ("grooming",     SpriteRowConfig(row: 13, frames: 2,  label: "Grooming face")),
        ("rollingOver",  SpriteRowConfig(row: 14, frames: 4,  label: "Rolling onto back", loops: false)),
        ("bellyCrawl",   SpriteRowConfig(row: 15, frames: 6,  label: "Belly crawl / exhausted")),
        ("slither",      SpriteRowConfig(row: 16, frames: 5,  label: "Flattened crawl / slither")),
        ("alerting",     SpriteRowConfig(row: 17, frames: 7,  label: "Walk with damage / hurt variant",
                                         skipColumns: [6])),
        ("dashing",      SpriteRowConfig(row: 18, frames: 6,  label: "Dash / burst movement")),
    ]

    /// Look up a row config by its string key.
    static func config(for key: String) -> SpriteRowConfig? {
        rows[key]
    }
}
