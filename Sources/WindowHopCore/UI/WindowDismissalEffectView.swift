import AppKit
import QuartzCore

/// One-shot window close effect with a fixed compositor budget.
///
/// v2.3 uses a deterministic low-discrepancy particle layout: particles begin
/// across the tile surface instead of from one center point, so the card reads
/// as dissolving rather than merely "popping". Count and duration are fixed,
/// therefore the effect remains O(1) and adds zero idle work.
final class WindowDismissalEffectView: NSView {
    private static let particleCount = 28
    private static let duration: CFTimeInterval = 0.29

    static var particleCountForTesting: Int { particleCount }
    static var animationDurationForTesting: CFTimeInterval { duration }

    private let snapshotView = NSImageView()

    init(frame frameRect: NSRect, snapshot: NSImage?) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false
        setAccessibilityElement(false)

        snapshotView.frame = bounds
        snapshotView.autoresizingMask = [.width, .height]
        snapshotView.image = snapshot
        snapshotView.imageScaling = .scaleAxesIndependently
        snapshotView.wantsLayer = true
        addSubview(snapshotView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func play() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            snapshotView.alphaValue = 0
            DispatchQueue.main.async { [weak self] in self?.removeFromSuperview() }
            return
        }

        animateSnapshot()
        animateGlassFlash()
        emitParticles()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.06) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    private func animateSnapshot() {
        guard let layer = snapshotView.layer else { return }

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1.0, 0.72, 0.0]
        fade.keyTimes = [0, 0.20, 1]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.008, 0.89]
        scale.keyTimes = [0, 0.15, 1]

        let blurLikeFade = CABasicAnimation(keyPath: "filters")
        blurLikeFade.fromValue = nil
        blurLikeFade.toValue = nil

        let group = CAAnimationGroup()
        group.animations = [fade, scale, blurLikeFade]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.80, 0.18, 1.0)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        layer.add(group, forKey: "windowDismissal")
    }

    private func animateGlassFlash() {
        guard let root = layer else { return }

        let flash = CAShapeLayer()
        let rect = bounds.insetBy(dx: 3, dy: 3)
        flash.frame = bounds
        flash.path = CGPath(
            roundedRect: rect,
            cornerWidth: DesignTokens.cardCornerRadius + 5,
            cornerHeight: DesignTokens.cardCornerRadius + 5,
            transform: nil)
        flash.fillColor = NSColor.keyboardFocusIndicatorColor
            .withAlphaComponent(0.05).cgColor
        flash.strokeColor = NSColor.keyboardFocusIndicatorColor
            .withAlphaComponent(0.72).cgColor
        flash.lineWidth = 1.4
        flash.opacity = 0
        root.addSublayer(flash)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.82, 0.0]
        opacity.keyTimes = [0, 0.14, 1]

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.985
        scale.toValue = 1.07

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = Self.duration * 0.82
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        flash.add(group, forKey: "glassFlash")
    }

    private func emitParticles() {
        guard let root = layer else { return }
        let baseTime = root.convertTime(CACurrentMediaTime(), from: nil)
        let count = Double(Self.particleCount)

        // Two irrational multipliers give a low-discrepancy 2D distribution
        // without randomness, storage, sorting, or per-frame generation.
        let xStep = 0.754_877_666
        let yStep = 0.569_840_296
        let goldenAngle = Double.pi * (3 - sqrt(5.0))

        for index in 0..<Self.particleCount {
            let i = Double(index + 1)
            let xUnit = fractional(i * xStep)
            let yUnit = fractional(i * yStep)
            let origin = CGPoint(
                x: bounds.width * (0.08 + 0.84 * xUnit),
                y: bounds.height * (0.10 + 0.80 * yUnit))

            let wave = index.isMultiple(of: 2) ? 1.0 : 0.72
            let angle = goldenAngle * i
            let distance = (48.0 + 32.0 * fractional(i / count + xUnit)) * wave
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance
            let destination = CGPoint(x: origin.x + dx, y: origin.y + dy)
            let curve = CGPoint(
                x: origin.x + dx * 0.48 - dy * 0.13,
                y: origin.y + dy * 0.48 + dx * 0.13)

            let accent = index % 3 != 1
            let size = CGFloat(2.8 + Double(index % 4) * 0.85)
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            dot.position = origin
            dot.cornerRadius = size / 2
            dot.backgroundColor = (accent
                ? NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.92)
                : NSColor.white.withAlphaComponent(0.88)).cgColor
            dot.shadowColor = NSColor.keyboardFocusIndicatorColor
                .withAlphaComponent(accent ? 0.30 : 0.10).cgColor
            dot.shadowOpacity = 1
            dot.shadowRadius = accent ? 2.6 : 1.2
            dot.shadowOffset = .zero
            root.addSublayer(dot)

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = [
                NSValue(point: origin),
                NSValue(point: curve),
                NSValue(point: destination),
            ]
            position.keyTimes = [0, 0.44, 1]

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 1.0, 0.82, 0.0]
            opacity.keyTimes = [0, 0.08, 0.34, 1]

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.45, accent ? 1.28 : 1.08, 0.10]
            scale.keyTimes = [0, 0.18, 1]

            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = index.isMultiple(of: 2) ? 1.8 : -1.8

            let group = CAAnimationGroup()
            group.animations = [position, opacity, scale, rotation]
            group.duration = Self.duration * (0.78 + Double(index % 5) * 0.035)
            group.beginTime = baseTime + Double(index % 7) * 0.006
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            dot.add(group, forKey: "particleDismissal")
        }
    }

    private func fractional(_ value: Double) -> Double {
        value - floor(value)
    }
}
