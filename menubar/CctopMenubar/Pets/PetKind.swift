import Foundation

enum PetKind: String, CaseIterable, Codable {
    case dog, cat, hamster

    var displayName: String { rawValue.capitalized }

    var spriteSheetName: String {
        switch self {
        case .dog: return "dog-sprites"
        case .cat: return "cat-sprites"
        case .hamster: return "hamster-sprites"
        }
    }

    /// Cell size in points (@1x). The asset catalog serves @2x on retina.
    var cellSize: CGSize {
        // All sprite sheets use 24x24pt cells (@1x), which is 48x48px @2x
        CGSize(width: 24, height: 24)
    }

    /// Cell size in pixels for the @2x sprite sheet (used by CGImage cropping).
    var cellSizePixels: Int { 48 }

    /// Maximum columns in the sprite sheet (widest row).
    var framesPerRow: Int {
        switch self {
        case .dog, .cat: return 6
        case .hamster: return 4
        }
    }

    var animationFPS: Double { 8 }

    /// SF Symbol used as placeholder sprite for each state.
    func placeholderSymbol(for state: PetState) -> String {
        switch (self, state) {
        case (_, .sleeping): return "moon.zzz.fill"
        case (_, .sitting): return "pause.circle.fill"
        case (.dog, .walking), (.dog, .running): return "dog.fill"
        case (.cat, .walking), (.cat, .running): return "cat.fill"
        case (.hamster, .walking), (.hamster, .running): return "hare.fill"
        case (_, .alerting): return "questionmark.circle.fill"
        case (_, .barking): return "exclamationmark.circle.fill"
        case (_, .spinning): return "arrow.triangle.2.circlepath"
        case (_, .appearing), (_, .disappearing): return "sparkle"
        }
    }

    /// Tint color for the placeholder.
    var placeholderHue: Double {
        switch self {
        case .dog: return 0.6    // blue
        case .cat: return 0.08   // orange
        case .hamster: return 0.07 // brown
        }
    }

    static func random() -> PetKind {
        allCases.randomElement() ?? .dog
    }
}
