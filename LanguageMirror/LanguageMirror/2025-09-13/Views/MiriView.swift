//
//  MiriView.swift
//  LanguageMirror
//
//  Miri — the app's mascot. A round mirror-sprite drawn entirely in code
//  (no image assets), so it scales crisply and recolors with the brand.
//  The name puns on "mirror" (미리 / Miri) and the character embodies the
//  core mechanic: it's your reflection, and it celebrates when you nail a
//  clip. Give it an expression and, optionally, let it wave or bounce.
//

import UIKit

final class MiriView: UIView {

    enum Expression {
        case happy      // default — gentle smile, open eyes
        case celebrating // big grin, sparkle eyes (completion)
        case sleeping   // closed eyes (empty / idle states)
    }

    var expression: Expression = .happy {
        didSet { setNeedsLayout() }
    }

    private let gradientLayer = CAGradientLayer()
    private let bodyMaskLayer = CAShapeLayer()
    private let highlightLayer = CAShapeLayer()   // glossy reflection sheen
    private let faceLayer = CAShapeLayer()        // eyes + mouth + cheeks

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        // Aqua→lavender body, clipped to a rounded-blob shape.
        gradientLayer.colors = AppColors.brandGradientColors
        gradientLayer.startPoint = CGPoint(x: 0.3, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.7, y: 1.0)
        gradientLayer.mask = bodyMaskLayer
        layer.addSublayer(gradientLayer)

        highlightLayer.fillColor = UIColor.white.withAlphaComponent(0.35).cgColor
        layer.addSublayer(highlightLayer)

        faceLayer.fillColor = UIColor(white: 0.12, alpha: 1.0).cgColor
        layer.addSublayer(faceLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds
        gradientLayer.frame = b

        // Body: a slightly-squashed rounded blob (softer than a circle).
        let inset = b.width * 0.06
        let bodyRect = b.insetBy(dx: inset, dy: inset * 1.4)
        bodyMaskLayer.path = UIBezierPath(
            roundedRect: bodyRect,
            cornerRadius: bodyRect.width * 0.46
        ).cgPath

        // Glossy top-left sheen — the "mirror" gleam.
        let sheen = UIBezierPath(ovalIn: CGRect(
            x: bodyRect.minX + bodyRect.width * 0.16,
            y: bodyRect.minY + bodyRect.height * 0.12,
            width: bodyRect.width * 0.30,
            height: bodyRect.height * 0.20
        ))
        highlightLayer.path = sheen.cgPath

        faceLayer.path = facePath(in: bodyRect).cgPath
        updateCheeks(in: bodyRect)
    }

    private var leftCheek = CAShapeLayer()
    private var rightCheek = CAShapeLayer()

    private func updateCheeks(in rect: CGRect) {
        for (cheek, cx) in [(leftCheek, 0.30), (rightCheek, 0.70)] {
            if cheek.superlayer == nil {
                cheek.fillColor = AppColors.brandSecondary.withAlphaComponent(0.55).cgColor
                layer.insertSublayer(cheek, below: faceLayer)
            }
            let r = rect.width * 0.075
            let x = rect.minX + rect.width * CGFloat(cx) - r
            let y = rect.minY + rect.height * 0.58
            cheek.path = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)).cgPath
        }
    }

    private func facePath(in rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let eyeY = rect.minY + rect.height * 0.46
        let eyeDX = rect.width * 0.20
        let leftEyeX = rect.midX - eyeDX
        let rightEyeX = rect.midX + eyeDX
        let eyeR = rect.width * 0.055

        switch expression {
        case .happy:
            path.append(dot(at: CGPoint(x: leftEyeX, y: eyeY), r: eyeR))
            path.append(dot(at: CGPoint(x: rightEyeX, y: eyeY), r: eyeR))
            path.append(smile(center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.62),
                              width: rect.width * 0.26, depth: rect.height * 0.06))
        case .celebrating:
            // Upward-arc "^ ^" happy eyes + big grin.
            path.append(arcEye(center: CGPoint(x: leftEyeX, y: eyeY), width: eyeR * 3, thickness: eyeR * 0.9))
            path.append(arcEye(center: CGPoint(x: rightEyeX, y: eyeY), width: eyeR * 3, thickness: eyeR * 0.9))
            path.append(smile(center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.60),
                              width: rect.width * 0.34, depth: rect.height * 0.10))
        case .sleeping:
            path.append(closedEye(center: CGPoint(x: leftEyeX, y: eyeY), width: eyeR * 2.6, thickness: eyeR * 0.7))
            path.append(closedEye(center: CGPoint(x: rightEyeX, y: eyeY), width: eyeR * 2.6, thickness: eyeR * 0.7))
            path.append(smile(center: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.62),
                              width: rect.width * 0.14, depth: rect.height * 0.03))
        }
        return path
    }

    // MARK: - Face primitives

    private func dot(at c: CGPoint, r: CGFloat) -> UIBezierPath {
        UIBezierPath(ovalIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    private func smile(center: CGPoint, width: CGFloat, depth: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let left = CGPoint(x: center.x - width / 2, y: center.y)
        let right = CGPoint(x: center.x + width / 2, y: center.y)
        let control = CGPoint(x: center.x, y: center.y + depth * 2.2)
        path.move(to: left)
        path.addQuadCurve(to: right, controlPoint: control)
        // Give the stroke some body by returning a thin filled crescent.
        let control2 = CGPoint(x: center.x, y: center.y + depth * 2.2 + max(2, depth * 0.5))
        path.addQuadCurve(to: left, controlPoint: control2)
        path.close()
        return path
    }

    private func arcEye(center: CGPoint, width: CGFloat, thickness: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let left = CGPoint(x: center.x - width / 2, y: center.y + thickness)
        let right = CGPoint(x: center.x + width / 2, y: center.y + thickness)
        let peak = CGPoint(x: center.x, y: center.y - thickness)
        path.move(to: left)
        path.addQuadCurve(to: right, controlPoint: peak)
        path.addLine(to: CGPoint(x: right.x, y: right.y + thickness))
        path.addQuadCurve(to: CGPoint(x: left.x, y: left.y + thickness),
                          controlPoint: CGPoint(x: center.x, y: center.y + thickness))
        path.close()
        return path
    }

    private func closedEye(center: CGPoint, width: CGFloat, thickness: CGFloat) -> UIBezierPath {
        UIBezierPath(roundedRect: CGRect(x: center.x - width / 2, y: center.y - thickness / 2,
                                         width: width, height: thickness),
                     cornerRadius: thickness / 2)
    }

    // MARK: - Animations

    /// A friendly greeting wobble — a gentle tilt back and forth.
    func wave() {
        let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        anim.values = [0, 0.18, -0.14, 0.10, 0]
        anim.keyTimes = [0, 0.25, 0.5, 0.75, 1]
        anim.duration = 1.0
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(anim, forKey: "wave")
    }

    /// A celebratory bounce with a little squash-and-stretch.
    func bounce() {
        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values = [1.0, 1.18, 0.94, 1.06, 1.0]
        anim.keyTimes = [0, 0.3, 0.55, 0.8, 1]
        anim.duration = 0.6
        anim.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(anim, forKey: "bounce")
    }

    /// Continuous gentle idle breathing, for hero placements.
    func startIdleFloat() {
        let float = CABasicAnimation(keyPath: "transform.translation.y")
        float.fromValue = -3
        float.toValue = 3
        float.duration = 2.2
        float.autoreverses = true
        float.repeatCount = .infinity
        float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(float, forKey: "idleFloat")
    }
}
