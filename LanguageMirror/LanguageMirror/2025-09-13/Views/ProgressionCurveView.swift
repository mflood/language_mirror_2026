//
//  ProgressionCurveView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 3/1/26.
//

import UIKit

final class ProgressionCurveView: UIView {

    private var minSpeed: Float = 0.6
    private var maxSpeed: Float = 1.0
    private var minRepeats: Int = 5
    private var linearRepeats: Int = 10
    private var maxRepeats: Int = 5

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = AppColors.cardBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        clipsToBounds = true
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(minSpeed: Float, maxSpeed: Float, minRepeats: Int, linearRepeats: Int, maxRepeats: Int) {
        self.minSpeed = minSpeed
        self.maxSpeed = maxSpeed
        self.minRepeats = max(1, minRepeats)
        self.linearRepeats = max(1, linearRepeats)
        self.maxRepeats = max(1, maxRepeats)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        let inset = UIEdgeInsets(top: 20, left: 44, bottom: 32, right: 16)
        let plotRect = rect.inset(by: inset)
        guard plotRect.width > 0, plotRect.height > 0 else { return }

        let totalLoops = minRepeats + linearRepeats + maxRepeats
        let M = minRepeats
        let N = linearRepeats

        let speedRange = maxSpeed - minSpeed
        let effectiveSpeedRange: Float = max(speedRange, 0.01)

        func xFor(loop: Int) -> CGFloat {
            plotRect.minX + plotRect.width * CGFloat(loop) / CGFloat(totalLoops)
        }
        func yFor(speed: Float) -> CGFloat {
            let ratio = CGFloat((speed - minSpeed) / effectiveSpeedRange)
            return plotRect.maxY - plotRect.height * ratio
        }

        // Fill phase regions
        let phaseColors: [(UIColor, Int, Int)] = [
            (AppColors.durationShort.withAlphaComponent(0.15), 0, M),
            (AppColors.durationMedium.withAlphaComponent(0.15), M, M + N),
            (AppColors.durationLong.withAlphaComponent(0.15), M + N, totalLoops),
        ]
        for (color, start, end) in phaseColors {
            let x0 = xFor(loop: start)
            let x1 = xFor(loop: end)
            let phaseRect = CGRect(x: x0, y: plotRect.minY, width: x1 - x0, height: plotRect.height)
            ctx.setFillColor(color.cgColor)
            ctx.fill(phaseRect)
        }

        // Build speed path
        let path = UIBezierPath()
        for loop in 0...totalLoops {
            let speed: Float
            if loop < M {
                speed = minSpeed
            } else if loop < M + N {
                let ratio = Float(loop - M) / Float(max(1, N - 1))
                speed = minSpeed + (maxSpeed - minSpeed) * min(ratio, 1.0)
            } else {
                speed = maxSpeed
            }
            let pt = CGPoint(x: xFor(loop: loop), y: yFor(speed: speed))
            if loop == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }

        ctx.setStrokeColor(AppColors.primaryAccent.cgColor)
        ctx.setLineWidth(2.5)
        ctx.addPath(path.cgPath)
        ctx.strokePath()

        // Y-axis speed labels
        let labelFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: AppColors.secondaryText,
        ]

        let minLabel = String(format: "%.1fx", minSpeed) as NSString
        let maxLabel = String(format: "%.1fx", maxSpeed) as NSString
        minLabel.draw(at: CGPoint(x: 4, y: yFor(speed: minSpeed) - 7), withAttributes: labelAttrs)
        maxLabel.draw(at: CGPoint(x: 4, y: yFor(speed: maxSpeed) - 7), withAttributes: labelAttrs)

        // Phase labels below the curve
        let phaseLabelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let phaseLabels: [(String, UIColor, Int, Int)] = [
            ("Start", AppColors.durationShort, 0, M),
            ("Ramp", AppColors.durationMedium, M, M + N),
            ("End", AppColors.durationLong, M + N, totalLoops),
        ]
        for (text, color, start, end) in phaseLabels {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: phaseLabelFont,
                .foregroundColor: color,
            ]
            let str = text as NSString
            let size = str.size(withAttributes: attrs)
            let centerX = (xFor(loop: start) + xFor(loop: end)) / 2
            str.draw(at: CGPoint(x: centerX - size.width / 2, y: plotRect.maxY + 8), withAttributes: attrs)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            setNeedsDisplay()
        }
    }
}
