#!/usr/bin/env swift
// RenderAppIcon.swift — standalone macOS CLI, not part of the app target.
// Run with:  swift Tools/RenderAppIcon.swift
// Writes three 1024×1024 PNGs directly into the AppIcon.appiconset folder.

import AppKit
import CoreGraphics
import Foundation
import SwiftUI

// ─────────────────────────────────────────────
// MARK: Geometry constants (1024×1024 canvas)
// ─────────────────────────────────────────────
private let kSize: CGFloat = 1024
private let kCenter = CGPoint(x: kSize / 2, y: kSize / 2)

// Crown: defined as fractions of canvas width, centered on 0.5
// Points: (x, y) pairs where y=0 is top
private let crownBaseY:  CGFloat = 0.60   // top of the base band
private let crownTopY:   CGFloat = 0.23   // tallest point tip
private let crownSideY:  CGFloat = 0.33   // outer point tips
private let crownBottomY:CGFloat = 0.72   // bottom of base band

private let crownLeft:   CGFloat = 0.20   // leftmost x
private let crownRight:  CGFloat = 0.80   // rightmost x

// ─────────────────────────────────────────────
// MARK: Crown Path (original geometry, not SF Symbol)
// ─────────────────────────────────────────────
func crownPath(in size: CGSize) -> Path {
    let w = size.width
    let h = size.height

    // Five-point crown: base trapezoid + three rising peaks
    // Working L→R: left edge, left outer peak, left inner valley,
    // center peak, right inner valley, right outer peak, right edge → base
    var p = Path()
    let pts: [(CGFloat, CGFloat)] = [
        (0.20, crownBottomY),    // BL corner
        (0.20, crownBaseY),      // left wall top
        (0.28, crownSideY),      // left outer peak
        (0.36, crownBaseY + 0.04), // left inner valley
        (0.50, crownTopY),       // center peak
        (0.64, crownBaseY + 0.04), // right inner valley
        (0.72, crownSideY),      // right outer peak
        (0.80, crownBaseY),      // right wall top
        (0.80, crownBottomY),    // BR corner
    ]
    let points = pts.map { CGPoint(x: $0.0 * w, y: $0.1 * h) }
    p.move(to: points[0])
    for pt in points.dropFirst() { p.addLine(to: pt) }
    p.closeSubpath()

    return p
}

// Three gem dots along the crown band
func gemDots(in size: CGSize) -> [(CGPoint, CGFloat)] {
    let w = size.width, h = size.height
    let r: CGFloat = 0.025 * w
    let y = (crownBaseY + crownBottomY) / 2 * h
    return [
        (CGPoint(x: 0.35 * w, y: y), r),
        (CGPoint(x: 0.50 * w, y: y), r * 1.2),
        (CGPoint(x: 0.65 * w, y: y), r),
    ]
}

// ─────────────────────────────────────────────
// MARK: Activity arc helper (NSBezierPath → CGPath)
// ─────────────────────────────────────────────
func arcPath(center: CGPoint, radius: CGFloat,
             startDeg: CGFloat, endDeg: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let startRad = startDeg * .pi / 180
    let endRad   = endDeg   * .pi / 180
    path.addArc(center: center, radius: radius,
                startAngle: startRad, endAngle: endRad,
                clockwise: false)
    return path
}

// ─────────────────────────────────────────────
// MARK: Render a single variant to CGImage
// ─────────────────────────────────────────────
enum Variant { case light, dark, tinted }

func renderIcon(variant: Variant) -> CGImage? {
    let size = CGSize(width: kSize, height: kSize)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    // Alpha: light icon must be opaque for App Store Connect
    let alphaInfo: CGImageAlphaInfo = (variant == .light) ? .noneSkipLast : .premultipliedLast
    guard let ctx = CGContext(
        data: nil, width: Int(kSize), height: Int(kSize),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: alphaInfo.rawValue
    ) else { return nil }

    // Flip coordinate system to match UIKit (origin top-left)
    ctx.translateBy(x: 0, y: kSize)
    ctx.scaleBy(x: 1, y: -1)

    // ── Background gradient ──
    let gradColors: [(CGFloat, CGFloat, CGFloat)]
    switch variant {
    case .light:
        gradColors = [(0.776, 0.443, 0.224), (0.549, 0.286, 0.102)]  // #c67139 → #8c491a
    case .dark:
        gradColors = [(0.227, 0.118, 0.047), (0.090, 0.047, 0.016)]  // #3a1e0c → #170c04
    case .tinted:
        gradColors = [(0.30, 0.30, 0.30), (0.10, 0.10, 0.10)]        // dark gray
    }
    let cgColors = gradColors.map { CGColor(srgbRed: $0.0, green: $0.1, blue: $0.2, alpha: 1.0) }
    let gradient = CGGradient(colorsSpace: colorSpace,
                              colors: cgColors as CFArray,
                              locations: [0.0, 1.0])!

    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: 0),
                           end:   CGPoint(x: kSize, y: kSize),
                           options: [])

    // Soft radial highlight (light/dark variants)
    if variant != .tinted {
        let hiColors = [
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12),
            CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
        ]
        let hiGrad = CGGradient(colorsSpace: colorSpace,
                                colors: hiColors as CFArray,
                                locations: [0.0, 1.0])!
        ctx.drawRadialGradient(hiGrad,
                               startCenter: CGPoint(x: kSize * 0.25, y: kSize * 0.20),
                               startRadius: 0,
                               endCenter: CGPoint(x: kSize * 0.25, y: kSize * 0.20),
                               endRadius: kSize * 0.70,
                               options: [])
    }

    // ── Activity arc ──
    let arcRadius: CGFloat = kSize * 0.38
    let arcCenter = CGPoint(x: kSize / 2, y: kSize / 2)
    let arcStart:  CGFloat = 130   // degrees (0° = right, CW in flipped coords)
    let arcEnd:    CGFloat = 50    // leaves a gap at bottom-left

    let arcStrokeWidth: CGFloat = kSize * 0.068
    let arcColor: CGColor
    switch variant {
    case .light, .dark: arcColor = CGColor(srgbRed: 0.961, green: 0.918, blue: 0.847, alpha: 0.85) // cream
    case .tinted:       arcColor = CGColor(srgbRed: 0.80, green: 0.80, blue: 0.80, alpha: 0.90)
    }

    let arcCGPath = arcPath(center: arcCenter, radius: arcRadius,
                            startDeg: arcStart, endDeg: arcEnd)

    ctx.setStrokeColor(arcColor)
    ctx.setLineWidth(arcStrokeWidth)
    ctx.setLineCap(.round)
    ctx.addPath(arcCGPath)
    ctx.strokePath()

    // Leading dot on arc (progress cap)
    let dotAngle = arcStart * CGFloat.pi / 180
    let dotCenter = CGPoint(
        x: arcCenter.x + arcRadius * cos(dotAngle),
        y: arcCenter.y + arcRadius * sin(dotAngle)
    )
    ctx.setFillColor(arcColor)
    ctx.fillEllipse(in: CGRect(
        x: dotCenter.x - arcStrokeWidth * 0.5,
        y: dotCenter.y - arcStrokeWidth * 0.5,
        width: arcStrokeWidth, height: arcStrokeWidth))

    // ── Crown ──
    let crownColor: CGColor
    let gemColor: CGColor
    switch variant {
    case .light, .dark:
        crownColor = CGColor(srgbRed: 0.961, green: 0.918, blue: 0.847, alpha: 1.0) // cream
        gemColor   = CGColor(srgbRed: 0.776, green: 0.443, blue: 0.224, alpha: 1.0) // orange
    case .tinted:
        crownColor = CGColor(srgbRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        gemColor   = CGColor(srgbRed: 0.50, green: 0.50, blue: 0.50, alpha: 1.0)
    }

    let crown = crownPath(in: CGSize(width: kSize, height: kSize)).cgPath
    ctx.addPath(crown)
    ctx.setFillColor(crownColor)
    ctx.fillPath()

    // Subtle inner gradient on crown (cream → near-white at top)
    // Draw as a clipped gradient
    ctx.saveGState()
    ctx.addPath(crown)
    ctx.clip()
    let crownHiColors = [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.30),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.0),
    ]
    let crownGrad = CGGradient(colorsSpace: colorSpace,
                               colors: crownHiColors as CFArray,
                               locations: [0, 1])!
    ctx.drawLinearGradient(crownGrad,
                           start: CGPoint(x: kSize * 0.5, y: kSize * crownTopY),
                           end:   CGPoint(x: kSize * 0.5, y: kSize * crownBottomY),
                           options: [])
    ctx.restoreGState()

    // Gem dots
    ctx.setFillColor(gemColor)
    for (center, radius) in gemDots(in: CGSize(width: kSize, height: kSize)) {
        ctx.fillEllipse(in: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2))
    }

    return ctx.makeImage()
}

// ─────────────────────────────────────────────
// MARK: Write PNG
// ─────────────────────────────────────────────
func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("ERROR: could not create PNG data for \(url.lastPathComponent)")
        return
    }
    do {
        try data.write(to: url)
        print("Wrote \(url.lastPathComponent) (\(data.count) bytes)")
    } catch {
        print("ERROR writing \(url.lastPathComponent): \(error)")
    }
}

// ─────────────────────────────────────────────
// MARK: Main
// ─────────────────────────────────────────────
let scriptDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let appiconsetDir = scriptDir
    .deletingLastPathComponent()
    .appendingPathComponent("PrimeMonarch/Assets.xcassets/AppIcon.appiconset")

print("Writing icons to: \(appiconsetDir.path)")

let variants: [(Variant, String)] = [
    (.light,  "AppIcon.png"),
    (.dark,   "AppIcon-Dark.png"),
    (.tinted, "AppIcon-Tinted.png"),
]

for (variant, filename) in variants {
    guard let image = renderIcon(variant: variant) else {
        print("ERROR: renderIcon failed for \(filename)")
        continue
    }
    let url = appiconsetDir.appendingPathComponent(filename)
    writePNG(image, to: url)
}

print("Done.")
