import Foundation

/// Each case is a color variant of the Pochi cat sprite sheet.
/// Sessions get a unique color assigned; once all 6 are taken, colors repeat.
enum PetKind: String, CaseIterable, Codable {
    case pochi          // default (calico/tabby)
    case pochiBlack     // black
    case pochiGrey      // grey
    case pochiGreyWhite // grey & white bicolor
    case pochiOrange    // orange
    case pochiWhite     // white

    var displayName: String {
        switch self {
        case .pochi:          return "Calico"
        case .pochiBlack:     return "Black"
        case .pochiGrey:      return "Grey"
        case .pochiGreyWhite: return "Grey & White"
        case .pochiOrange:    return "Orange"
        case .pochiWhite:     return "White"
        }
    }

    /// Asset catalog name for the combined sprite sheet.
    var spriteSheetName: String {
        switch self {
        case .pochi:          return "pochi-default"
        case .pochiBlack:     return "pochi-black"
        case .pochiGrey:      return "pochi-grey"
        case .pochiGreyWhite: return "pochi-greywhite"
        case .pochiOrange:    return "pochi-orange"
        case .pochiWhite:     return "pochi-white"
        }
    }

    /// Cell size in points. The Pochi sheets are 64x64 px at 1x.
    var cellSize: CGSize { CGSize(width: 64, height: 64) }

    /// Cell size in pixels for CGImage cropping.
    var cellSizePixels: Int { 64 }

    /// Maximum columns in the sprite sheet (1024 / 64 = 16).
    var framesPerRow: Int { 16 }

    var animationFPS: Double { 8 }

    /// SF Symbol fallback if sprite sheet fails to load.
    func placeholderSymbol(for state: PetState) -> String {
        switch state {
        case .sleeping:    return "moon.zzz.fill"
        case .sitting:     return "pause.circle.fill"
        case .walking:     return "cat.fill"
        case .running:     return "cat.fill"
        case .alerting:    return "exclamationmark.triangle.fill"
        case .barking:     return "exclamationmark.circle.fill"
        case .spinning:    return "arrow.triangle.2.circlepath"
        case .sneaking:    return "cat.fill"
        case .dashing:     return "bolt.fill"
        case .standing:    return "figure.stand"
        case .boxIdle:     return "shippingbox.fill"
        case .boxWiggle:   return "shippingbox.fill"
        case .dancing:     return "sparkles"
        case .crying:      return "cloud.rain.fill"
        case .grooming:    return "hands.sparkles.fill"
        case .lookingUp:   return "eye.fill"
        case .rollingOver: return "arrow.uturn.down"
        case .appearing, .disappearing: return "sparkle"
        }
    }

    var placeholderHue: Double {
        switch self {
        case .pochi:          return 0.08   // warm
        case .pochiBlack:     return 0.0    // neutral
        case .pochiGrey:      return 0.0    // neutral
        case .pochiGreyWhite: return 0.55   // cool
        case .pochiOrange:    return 0.08   // orange
        case .pochiWhite:     return 0.0    // neutral
        }
    }

    /// Pick a random color that isn't already used by any of the given kinds.
    /// If all colors are taken, falls back to a random pick.
    static func randomUnassigned(excluding used: Set<PetKind>) -> PetKind {
        let available = allCases.filter { !used.contains($0) }
        return available.randomElement() ?? allCases.randomElement()!
    }
}
