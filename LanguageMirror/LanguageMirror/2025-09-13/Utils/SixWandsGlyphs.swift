//
//  SixWandsGlyphs.swift
//  LanguageMirror
//
//  The engraved-line icon family of the Six Wands universe (see
//  brand/miri/): thin single-weight strokes drawn in code, rendered as
//  template images so the tab bar tint applies. One consistent stroke
//  weight across the set — these read as engravings, not SF Symbols.
//

import UIKit

enum SixWandsGlyphs {

    private static let canvas = CGSize(width: 25, height: 25)
    private static let stroke: CGFloat = 1.7

    private static func draw(_ body: (CGContext) -> Void) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: canvas)
        return renderer.image { ctx in
            let c = ctx.cgContext
            c.setLineWidth(stroke)
            c.setLineCap(.round)
            c.setLineJoin(.round)
            c.setStrokeColor(UIColor.black.cgColor)
            c.setFillColor(UIColor.black.cgColor)
            body(c)
        }.withRenderingMode(.alwaysTemplate)
    }

    /// Practice — Miri's hand mirror: glass circle with fringe line,
    /// dot eyes, and a stem handle.
    static var handMirror: UIImage {
        draw { c in
            let center = CGPoint(x: 12.5, y: 9.5)
            let r: CGFloat = 7.5
            c.strokeEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))

            // Handle
            c.move(to: CGPoint(x: center.x, y: center.y + r))
            c.addLine(to: CGPoint(x: center.x, y: 22.5))
            c.strokePath()

            // Fringe (bangs) across the upper glass
            c.addArc(center: CGPoint(x: center.x, y: center.y + 0.4), radius: r - 3.0,
                     startAngle: .pi * 1.08, endAngle: .pi * 1.92, clockwise: false)
            c.strokePath()

            // Eyes
            for ex in [center.x - 2.9, center.x + 2.9] {
                c.fillEllipse(in: CGRect(x: ex - 1.2, y: center.y + 1.8, width: 2.4, height: 2.4))
            }

            // Smile
            c.addArc(center: CGPoint(x: center.x, y: center.y + 3.4), radius: 1.9,
                     startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            c.strokePath()
        }
    }

    /// Library — a herald wand-trumpet seen from the side: horizontal
    /// shaft, open flaring bell to the right, finial ball at the grip.
    static var wandTrumpet: UIImage {
        draw { c in
            let axisY: CGFloat = 12.5
            let grip = CGPoint(x: 4, y: axisY)
            let throat = CGPoint(x: 14.5, y: axisY)
            c.move(to: grip); c.addLine(to: throat)
            c.strokePath()

            // Open bell: two flaring curves, no closing arc
            c.move(to: throat)
            c.addQuadCurve(to: CGPoint(x: 21.5, y: 5.5), control: CGPoint(x: 17.5, y: 10.5))
            c.move(to: throat)
            c.addQuadCurve(to: CGPoint(x: 21.5, y: 19.5), control: CGPoint(x: 17.5, y: 14.5))
            c.strokePath()
            // Bell mouth
            c.move(to: CGPoint(x: 21.5, y: 5.5))
            c.addQuadCurve(to: CGPoint(x: 21.5, y: 19.5), control: CGPoint(x: 20.2, y: 12.5))
            c.strokePath()

            // Finial
            c.fillEllipse(in: CGRect(x: grip.x - 1.8, y: grip.y - 1.8, width: 3.6, height: 3.6))
        }
    }

    /// Import — a sealed envelope, wax seal on the flap point.
    static var sealedEnvelope: UIImage {
        draw { c in
            let rect = CGRect(x: 3.5, y: 6, width: 18, height: 13.5)
            c.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 2).cgPath)
            c.strokePath()

            // Flap
            c.move(to: CGPoint(x: rect.minX + 0.6, y: rect.minY + 1.2))
            c.addLine(to: CGPoint(x: rect.midX, y: rect.minY + 7.4))
            c.addLine(to: CGPoint(x: rect.maxX - 0.6, y: rect.minY + 1.2))
            c.strokePath()

            // Wax seal
            c.fillEllipse(in: CGRect(x: rect.midX - 2.1, y: rect.minY + 5.6, width: 4.2, height: 4.2))
        }
    }

    /// Settings — an I Ching hexagram, mixed solid and broken lines.
    static var hexagram: UIImage {
        draw { c in
            let left: CGFloat = 4.5, right: CGFloat = 20.5, midGap: CGFloat = 3.2
            let broken: Set<Int> = [1, 4]  // counted from the top, 0-based
            for i in 0..<6 {
                let y = 3.5 + CGFloat(i) * 3.6
                if broken.contains(i) {
                    c.move(to: CGPoint(x: left, y: y))
                    c.addLine(to: CGPoint(x: 12.5 - midGap, y: y))
                    c.move(to: CGPoint(x: 12.5 + midGap, y: y))
                    c.addLine(to: CGPoint(x: right, y: y))
                } else {
                    c.move(to: CGPoint(x: left, y: y))
                    c.addLine(to: CGPoint(x: right, y: y))
                }
            }
            c.strokePath()
        }
    }
}
