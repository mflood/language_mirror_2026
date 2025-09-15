//
//  LevelMeterView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Views/LevelMeterView.swift
import UIKit

final class LevelMeterView: UIView {
    private let title = UILabel()
    private let rmsBar = UIProgressView(progressViewStyle: .default)
    private let peakBar = UIProgressView(progressViewStyle: .default)
    private let rmsLabel = UILabel()
    private let peakLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        title.text = "Selection level"
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        [rmsLabel, peakLabel].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabel
        }
        rmsLabel.text = "RMS — dB"
        peakLabel.text = "Peak — dB"

        [title, rmsBar, rmsLabel, peakBar, peakLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor),
            title.leadingAnchor.constraint(equalTo: leadingAnchor),

            rmsBar.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            rmsBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            rmsBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            rmsLabel.topAnchor.constraint(equalTo: rmsBar.bottomAnchor, constant: 2),
            rmsLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            peakBar.topAnchor.constraint(equalTo: rmsLabel.bottomAnchor, constant: 8),
            peakBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            peakBar.trailingAnchor.constraint(equalTo: trailingAnchor),

            peakLabel.topAnchor.constraint(equalTo: peakBar.bottomAnchor, constant: 2),
            peakLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            peakLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(rms: Double, peak: Double) {
        rmsBar.progress = Float(rms)
        peakBar.progress = Float(peak)
        rmsLabel.text = String(format: "RMS  %.1f dBFS", rms.dbFS)
        peakLabel.text = String(format: "Peak %.1f dBFS", peak.dbFS)
    }

    func reset() {
        update(rms: 0, peak: 0)
    }
}
