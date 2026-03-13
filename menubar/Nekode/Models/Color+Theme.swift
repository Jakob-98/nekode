import AppKit
import SwiftUI

extension Color {
    /// Create a dynamic color that adapts to dark/light appearance.
    /// Both parameters are NSColor instances.
    static func dynamic(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    /// Orange-coral accent — the primary brand color. Dark: #e76f51, Light: #c85a3e
    static let amber = dynamic(
        dark: NSColor(red: 231 / 255, green: 111 / 255, blue: 81 / 255, alpha: 1),
        light: NSColor(red: 200 / 255, green: 90 / 255, blue: 62 / 255, alpha: 1)
    )

    /// Segmented control background. Dark: #111417, Light: #e4e8ec
    static let segmentBackground = dynamic(
        dark: NSColor(red: 17 / 255, green: 20 / 255, blue: 23 / 255, alpha: 1),
        light: NSColor(red: 228 / 255, green: 232 / 255, blue: 236 / 255, alpha: 1)
    )

    /// Segmented control inactive text. Dark: #6b7a85, Light: #6b7a85
    static let segmentText = dynamic(
        dark: NSColor(red: 107 / 255, green: 122 / 255, blue: 133 / 255, alpha: 1),
        light: NSColor(red: 107 / 255, green: 122 / 255, blue: 133 / 255, alpha: 1)
    )

    /// Active segment text. Dark: #111417, Light: #ffffff
    static let segmentActiveText = dynamic(
        dark: NSColor(red: 17 / 255, green: 20 / 255, blue: 23 / 255, alpha: 1),
        light: NSColor.white
    )

    /// Settings section background. Dark: #1a1e22, Light: #f0f2f4
    static let settingsBackground = dynamic(
        dark: NSColor(red: 26 / 255, green: 30 / 255, blue: 34 / 255, alpha: 1),
        light: NSColor(red: 240 / 255, green: 242 / 255, blue: 244 / 255, alpha: 1)
    )

    /// Settings section border. Dark: #2f353c, Light: #d0d5da
    static let settingsBorder = dynamic(
        dark: NSColor(red: 47 / 255, green: 53 / 255, blue: 60 / 255, alpha: 1),
        light: NSColor(red: 208 / 255, green: 213 / 255, blue: 218 / 255, alpha: 1)
    )

    /// Panel background. Dark: #141719, Light: #f5f6f8
    static let panelBackground = dynamic(
        dark: NSColor(red: 20 / 255, green: 23 / 255, blue: 25 / 255, alpha: 1),
        light: NSColor(red: 245 / 255, green: 246 / 255, blue: 248 / 255, alpha: 1)
    )

    /// Card background. Dark: #23282e, Light: #ffffff
    static let cardBackground = dynamic(
        dark: NSColor(red: 35 / 255, green: 40 / 255, blue: 46 / 255, alpha: 1),
        light: NSColor.white
    )

    /// Card border. Dark: #2f353c, Light: #d0d5da
    static let cardBorder = dynamic(
        dark: NSColor(red: 47 / 255, green: 53 / 255, blue: 60 / 255, alpha: 1),
        light: NSColor(red: 208 / 255, green: 213 / 255, blue: 218 / 255, alpha: 1)
    )

    /// Working status green. Dark: #8fcb9b, Light: #5b9279
    static let statusGreen = dynamic(
        dark: NSColor(red: 143 / 255, green: 203 / 255, blue: 155 / 255, alpha: 1),
        light: NSColor(red: 91 / 255, green: 146 / 255, blue: 121 / 255, alpha: 1)
    )

    /// Secondary text — context lines, labels. Dark: #8fcb9b, Light: #4a6e5c
    static let textSecondary = dynamic(
        dark: NSColor(red: 143 / 255, green: 203 / 255, blue: 155 / 255, alpha: 1),
        light: NSColor(red: 74 / 255, green: 110 / 255, blue: 92 / 255, alpha: 1)
    )

    /// Muted text — timestamps, versions, branch names. Dark: #6b7a85, Light: #8a939c
    static let textMuted = dynamic(
        dark: NSColor(red: 107 / 255, green: 122 / 255, blue: 133 / 255, alpha: 1),
        light: NSColor(red: 138 / 255, green: 147 / 255, blue: 156 / 255, alpha: 1)
    )
}
