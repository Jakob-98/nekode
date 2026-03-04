import AppKit
import SwiftUI

// MARK: - Sprite Sheet Cache

/// Caches loaded and sliced sprite frames to avoid re-cropping every tick.
/// Uses CGImage-based cropping to correctly handle @2x Retina sprites.
@MainActor
final class SpriteSheetCache {
    static let shared = SpriteSheetCache()

    /// Cache key: "kind-row-col"
    private var frameCache: [String: NSImage] = [:]
    /// Cached CGImage + pixel dimensions per sheet
    private var sheetCache: [String: (cgImage: CGImage, pxW: Int, pxH: Int)] = [:]

    func frame(
        kind: PetKind, row: Int, column: Int
    ) -> NSImage? {
        let key = "\(kind.rawValue)-\(row)-\(column)"
        if let cached = frameCache[key] {
            return cached
        }

        guard let sheet = loadSheet(kind: kind) else { return nil }

        // Work in pixels — the CGImage is the full @2x bitmap
        let cellPx = kind.cellSizePixels
        let srcX = column * cellPx
        let srcY = row * cellPx   // Row 0 = top of image, CGImage (0,0) = top-left ✓

        // Bounds check in pixels
        guard srcX + cellPx <= sheet.pxW,
              srcY + cellPx <= sheet.pxH else {
            return nil
        }

        let cropRect = CGRect(x: srcX, y: srcY, width: cellPx, height: cellPx)
        guard let croppedCG = sheet.cgImage.cropping(to: cropRect) else {
            return nil
        }

        // Create NSImage with correct backing scale so it renders sharp
        // on Retina. Point size = pixel size / 2 for @2x.
        let pointSize = kind.cellSize
        let result = NSImage(cgImage: croppedCG, size: pointSize)

        frameCache[key] = result
        return result
    }

    private func loadSheet(
        kind: PetKind
    ) -> (cgImage: CGImage, pxW: Int, pxH: Int)? {
        let name = kind.spriteSheetName
        if let cached = sheetCache[name] {
            return cached
        }
        guard let nsImage = NSImage(named: name) else { return nil }

        // Get the highest-resolution CGImage representation (the @2x bitmap)
        guard let cgImage = nsImage.bestCGImage() else { return nil }
        let entry = (
            cgImage: cgImage,
            pxW: cgImage.width,
            pxH: cgImage.height
        )
        sheetCache[name] = entry
        return entry
    }

    func clearCache() {
        frameCache.removeAll()
        sheetCache.removeAll()
    }
}

// MARK: - NSImage CGImage Helper

extension NSImage {
    /// Returns the best (highest-resolution) CGImage from the image's reps.
    func bestCGImage() -> CGImage? {
        // Prefer the largest bitmap representation
        var best: CGImage?
        var bestPixels = 0
        for rep in representations {
            if let bitmapRep = rep as? NSBitmapImageRep,
               let cg = bitmapRep.cgImage {
                let pixels = cg.width * cg.height
                if pixels > bestPixels {
                    best = cg
                    bestPixels = pixels
                }
            }
        }
        if let best { return best }
        // Fallback: render into a CGContext at 2x
        let pxW = Int(size.width * 2)
        let pxH = Int(size.height * 2)
        guard let ctx = CGContext(
            data: nil, width: pxW, height: pxH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        draw(in: CGRect(x: 0, y: 0, width: pxW, height: pxH))
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()
    }
}

// MARK: - Sprite Sheet View

/// Renders a single frame from a sprite sheet PNG stored in the asset catalog.
/// Uses a cache to avoid re-cropping on every animation tick.
struct SpriteSheetView: View {
    let kind: PetKind
    let state: PetState
    let frame: Int
    let petSize: CGFloat

    var body: some View {
        if let frameImage = SpriteSheetCache.shared.frame(
            kind: kind,
            row: state.spriteRow,
            column: frame
        ) {
            Image(nsImage: frameImage)
                .interpolation(.none)     // Pixel-perfect scaling
                .resizable()
                .frame(width: petSize, height: petSize)
        } else {
            // Fallback if sprite sheet not found in asset catalog
            PlaceholderSprite(
                kind: kind,
                state: state,
                frame: frame,
                petSize: petSize
            )
        }
    }
}
