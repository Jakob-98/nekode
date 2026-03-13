import AppKit
import SwiftUI

extension Color {
    /// Teal accent — the primary brand color. Dark: #2DD4BF, Light: #0D9488
    static let amber = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 45 / 255, green: 212 / 255, blue: 191 / 255, alpha: 1)
            : NSColor(red: 13 / 255, green: 148 / 255, blue: 136 / 255, alpha: 1)
    })

    /// Segmented control background. Dark: #0f1a1a, Light: #d0e5e3
    static let segmentBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 15 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)
            : NSColor(red: 208 / 255, green: 229 / 255, blue: 227 / 255, alpha: 1)
    })

    /// Segmented control inactive text. Dark: #5a7a76, Light: #708d89
    static let segmentText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 90 / 255, green: 122 / 255, blue: 118 / 255, alpha: 1)
            : NSColor(red: 112 / 255, green: 141 / 255, blue: 137 / 255, alpha: 1)
    })

    /// Active segment text. Dark: #0f1a1a, Light: #ffffff
    static let segmentActiveText = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 15 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)
            : NSColor.white
    })

    /// Settings section background. Dark: #172625, Light: #D8EDE9
    static let settingsBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 23 / 255, green: 38 / 255, blue: 37 / 255, alpha: 1)
            : NSColor(red: 216 / 255, green: 237 / 255, blue: 233 / 255, alpha: 1)
    })

    /// Settings section border. Dark: #2a3d3b, Light: #c8ddd9
    static let settingsBorder = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 42 / 255, green: 61 / 255, blue: 59 / 255, alpha: 1)
            : NSColor(red: 200 / 255, green: 221 / 255, blue: 217 / 255, alpha: 1)
    })

    /// Panel background. Dark: #14221f, Light: #EDF5F4
    static let panelBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 20 / 255, green: 34 / 255, blue: 31 / 255, alpha: 1)
            : NSColor(red: 237 / 255, green: 245 / 255, blue: 244 / 255, alpha: 1)
    })

    /// Card background. Dark: #1b2e2b, Light: #ffffff
    static let cardBackground = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 27 / 255, green: 46 / 255, blue: 43 / 255, alpha: 1)
            : NSColor.white
    })

    /// Card border. Dark: #2a3d3b, Light: #c8ddd9
    static let cardBorder = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 42 / 255, green: 61 / 255, blue: 59 / 255, alpha: 1)
            : NSColor(red: 200 / 255, green: 221 / 255, blue: 217 / 255, alpha: 1)
    })

    /// Working status green. Dark: #4ade80, Light: #2da55e
    static let statusGreen = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 74 / 255, green: 222 / 255, blue: 128 / 255, alpha: 1)
            : NSColor(red: 45 / 255, green: 165 / 255, blue: 94 / 255, alpha: 1)
    })

    /// Secondary text — context lines, labels. Dark: #82C4B8, Light: #38504d
    static let textSecondary = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 130 / 255, green: 196 / 255, blue: 184 / 255, alpha: 1)
            : NSColor(red: 56 / 255, green: 80 / 255, blue: 77 / 255, alpha: 1)
    })

    /// Muted text — timestamps, versions, branch names. Dark: #5a7a76, Light: #708d89
    static let textMuted = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 90 / 255, green: 122 / 255, blue: 118 / 255, alpha: 1)
            : NSColor(red: 112 / 255, green: 141 / 255, blue: 137 / 255, alpha: 1)
    })
}
