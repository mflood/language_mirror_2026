//
//  HexagramMeterView.swift
//  LanguageMirror
//
//  Loop progress as an I Ching hexagram: six horizontal lines that fill
//  with antique gold from the bottom up as the loop set completes.
//  Finish every loop and you've drawn Hexagram 1, The Creative — the
//  six unbroken lines from the Six Wands mark. Replaces the plain
//  "Loop 6/8" nav title during playback; the numbers stay alongside in
//  a small serif label and in the accessibility label.
//

import UIKit

final class HexagramMeterView: UIView {

    private let linesView = LinesView()
    private let label = UILabel()

    init() {
        super.init(frame: .zero)

        label.font = AppFont.plate(14, weight: .semibold)
        label.textColor = AppColors.antiqueGold

        let stack = UIStackView(arrangedSubviews: [linesView, label])
        stack.axis = .horizontal
        stack.spacing = 7
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            linesView.widthAnchor.constraint(equalToConstant: 20),
            linesView.heightAnchor.constraint(equalToConstant: 19),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .updatesFrequently
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(currentLoop: Int, totalLoops: Int) {
        label.text = "\(currentLoop)/\(totalLoops)"
        linesView.filled = totalLoops > 0
            ? Int((Double(currentLoop) / Double(totalLoops) * 6).rounded())
            : 0
        accessibilityLabel = L10nf("practice.title_with_loop", currentLoop, totalLoops)
    }

    private final class LinesView: UIView {

        var filled = 0 {
            didSet { if filled != oldValue { setNeedsDisplay() } }
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            contentMode = .redraw
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: LinesView, _) in
                view.setNeedsDisplay()
            }
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func draw(_ rect: CGRect) {
            let lineHeight: CGFloat = 2
            let gap = (rect.height - 6 * lineHeight) / 5
            for i in 0..<6 {
                // i counts from the bottom, the way a hexagram is built
                let y = rect.maxY - lineHeight - CGFloat(i) * (lineHeight + gap)
                let bar = UIBezierPath(
                    roundedRect: CGRect(x: 0, y: y, width: rect.width, height: lineHeight),
                    cornerRadius: lineHeight / 2)
                (i < filled ? AppColors.antiqueGold : AppColors.goldHairline).setFill()
                bar.fill()
            }
        }
    }
}
