//
//  WaveformView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//

import AVFoundation
import UIKit

final class WaveformView: UIView {
    private let shape = CAShapeLayer(); private(set) var sampleCount = 0
    private var levels: [Float] = [] { didSet { sampleCount = levels.count } }
    var amplitudeScale: CGFloat = 1.5  // 🔧 new public property to control vertical exaggeration

    private let maxSamples = 300
    
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        layer.addSublayer(shape)
        shape.lineWidth = 2
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeColor = UIColor.red.cgColor
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        layer.addSublayer(shape)
        shape.lineWidth = 2
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeColor = UIColor.red.cgColor
    }

    func update(with newLevels: [Float]) {
        levels.append(contentsOf: newLevels)

        if levels.count > maxSamples { levels.removeFirst(levels.count - maxSamples) }

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard !levels.isEmpty else { return }
        let path = UIBezierPath()
        let h = bounds.midY
        let step = bounds.width / CGFloat(max(levels.count - 1, 1))

        for (i, l) in levels.enumerated() {
            let x = CGFloat(i) * step
            let y = h - min(CGFloat(l) * amplitudeScale, 1.0) * h
            i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
        }

        shape.path = path.cgPath
    }
}
