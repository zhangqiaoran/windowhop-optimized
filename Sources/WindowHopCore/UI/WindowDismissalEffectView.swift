import AppKit
import QuartzCore

/// One-shot close flourish with a fixed amount of compositor work.
///
/// v2.2 uses two deterministic particle waves distributed across the tile
/// surface instead of emitting every dot from the center. The count is fixed,
/// there is no timer/polling loop, and every transient layer self-destructs.
final class WindowDismissalEffectView: NSView {
    private struct ParticleSpec {
        let x: CGFloat
        let y: CGFloat
        let dx: CGFloat
        let dy: CGFloat
        let size: CGFloat
        let delay: CFTimeInterval
        let accent: Bool
    }

    private static let duration: CFTimeInterval = 0.34

    /// Fixed 18-particle burst: enough visual density to read as dissolution,
    /// but still O(1) regardless of window count or preview size.
    private static let particles: [ParticleSpec] = [
        .init(x: 0.12, y: 0.78, dx: -52, dy: 34, size: 6, delay: 0.00, accent: true),
        .init(x: 0.26, y: 0.84, dx: -30, dy: 58, size: 4, delay: 0.01, accent: false),
        .init(x: 0.43, y: 0.88, dx: -10, dy: 68, size: 5, delay: 0.00, accent: true),
        .init(x: 0.61, y: 0.86, dx: 18, dy: 62, size: 4, delay: 0.02, accent: false),
        .init(x: 0.78, y: 0.80, dx: 44, dy: 48, size: 6, delay: 0.01, accent: true),
        .init(x: 0.88, y: 0.66, dx: 62, dy: 22, size: 4, delay: 0.03, accent: false),

        .init(x: 0.90, y: 0.46, dx: 70, dy: -4, size: 5, delay: 0.00, accent: true),
        .init(x: 0.84, y: 0.26, dx: 56, dy: -42, size: 4, delay: 0.02, accent: false),
        .init(x: 0.69, y: 0.14, dx: 30, dy: -60, size: 6, delay: 0.01, accent: true),
        .init(x: 0.50, y: 0.12, dx: 4, dy: -68, size: 4, delay: 0.04, accent: false),
        .init(x: 0.31, y: 0.16, dx: -28, dy: -58, size: 5, delay: 0.02, accent: true),
        .init(x: 0.14, y: 0.28, dx: -56, dy: -38, size: 4, delay: 0.03, accent: false),

        .init(x: 0.08, y: 0.48, dx: -70, dy: 0, size: 5, delay: 0.00, accent: true),
        .init(x: 0.18, y: 0.60, dx: -46, dy: 16, size: 3, delay: 0.055, accent: false),
        .init(x: 0.35, y: 0.64, dx: -20, dy: 30, size: 4, delay: 0.045, accent: false),
        .init(x: 0.55, y: 0.58, dx: 20, dy: 22, size: 3, delay: 0.06, accent: true),
        .init(x: 0.72, y: 0.54, dx: 40, dy: 10, size: 4, delay: 0.05, accent: false),
        .init(x: 0.48, y: 0.38, dx: 8, dy: -28, size: 3, delay: 0.07, accent: true),
    ]

    static var particleCountForTesting: Int { particles.count }
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

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.12) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    private func animateSnapshot() {
        guard let layer = snapshotView.layer else { return }

        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1.0, 0.88, 0.0]
        fade.keyTimes = [0, 0.24, 1]

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 1.012, 0.90]
        scale.keyTimes = [0, 0.18, 1]

        let tilt = CABasicAnimation(keyPath: "transform.rotation.z")
        tilt.fromValue = 0
        tilt.toValue = -0.018

        let group = CAAnimationGroup()
        group.animations = [fade, scale, tilt]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.76, 0.22, 1.0)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        layer.add(group, forKey: "windowDismissal")
    }

    private func animateGlassFlash() {
        guard let root = layer else { return }

        let flash = CAShapeLayer()
        let rect = bounds.insetBy(dx: 4, dy: 4)
        flash.frame = bounds
        flash.path = CGPath(
            roundedRect: rect,
            cornerWidth: DesignTokens.cardCornerRadius + 4,
            cornerHeight: DesignTokens.cardCornerRadius + 4,
            transform: nil)
        flash.fillColor = NSColor.clear.cgColor
        flash.strokeColor = NSColor.keyboardFocusIndicatorColor
            .withAlphaComponent(0.62).cgColor
        flash.lineWidth = 1.5
        flash.opacity = 0
        root.addSublayer(flash)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.75, 0.0]
        opacity.keyTimes = [0, 0.18, 1]

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.985
        scale.toValue = 1.055

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = Self.duration * 0.72
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        flash.add(group, forKey: "glassFlash")
    }

    private func emitParticles() {
        guard let root = layer else { return }
        let baseTime = root.convertTime(CACurrentMediaTime(), from: nil)

        for (index, spec) in Self.particles.enumerated() {
            let origin = CGPoint(x: bounds.width * spec.x, y: bounds.height * spec.y)
            let destination = CGPoint(x: origin.x + spec.dx, y: origin.y + spec.dy)
            let curve = CGPoint(
                x: origin.x + spec.dx * 0.46 - spec.dy * 0.10,
                y: origin.y + spec.dy * 0.46 + spec.dx * 0.10)

            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: spec.size, height: spec.size)
            dot.position = origin
            dot.cornerRadius = spec.size / 2
            dot.backgroundColor = (spec.accent
                ? NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.92)
                : NSColor.white.withAlphaComponent(0.86)).cgColor
            dot.shadowColor = NSColor.keyboardFocusIndicatorColor
                .withAlphaComponent(spec.accent ? 0.35 : 0.12).cgColor
            dot.shadowOpacity = 1
            dot.shadowRadius = spec.accent ? 3 : 1.5
            dot.shadowOffset = .zero
            root.addSublayer(dot)

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = [
                NSValue(point: origin),
                NSValue(point: curve),
                NSValue(point: destination),
            ]
            position.keyTimes = [0, 0.48, 1]

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.15, 1.0, 0.0]
            opacity.keyTimes = [0, 0.16, 1]

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.55, spec.accent ? 1.18 : 1.0, 0.12]
            scale.keyTimes = [0, 0.24, 1]

            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = 0
            rotation.toValue = (index.isMultiple(of: 2) ? 1.4 : -1.4)

            let group = CAAnimationGroup()
            group.animations = [position, opacity, scale, rotation]
            group.duration = Self.duration * (0.74 + Double(index % 4) * 0.045)
            group.beginTime = baseTime + spec.delay
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            dot.add(group, forKey: "particleDismissal")
        }
    }
}
