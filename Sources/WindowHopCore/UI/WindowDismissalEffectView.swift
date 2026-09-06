import AppKit
import QuartzCore

/// One-shot close animation. The particle count is intentionally fixed, so
/// closing a window has bounded O(1) compositor work and adds zero idle cost.
final class WindowDismissalEffectView: NSView {
    private static let duration: CFTimeInterval = 0.26
    private static let vectors: [CGPoint] = [
        CGPoint(x: -52, y: 10), CGPoint(x: -42, y: 38),
        CGPoint(x: -18, y: 54), CGPoint(x: 12, y: 58),
        CGPoint(x: 40, y: 42), CGPoint(x: 56, y: 14),
        CGPoint(x: 50, y: -20), CGPoint(x: 28, y: -48),
        CGPoint(x: -4, y: -58), CGPoint(x: -34, y: -44),
        CGPoint(x: -56, y: -16), CGPoint(x: 22, y: 28),
    ]

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
        emitParticles()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.05) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    private func animateSnapshot() {
        guard let layer = snapshotView.layer else { return }

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 0.92

        let group = CAAnimationGroup()
        group.animations = [fade, scale]
        group.duration = Self.duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 0.78, 0.22, 1.0)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        layer.add(group, forKey: "windowDismissal")
    }

    private func emitParticles() {
        guard let root = layer else { return }
        let origin = CGPoint(x: bounds.midX, y: bounds.midY)

        for (index, vector) in Self.vectors.enumerated() {
            let dot = CALayer()
            let size = CGFloat(4 + (index % 3))
            dot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            dot.position = origin
            dot.cornerRadius = size / 2
            dot.backgroundColor = (index.isMultiple(of: 3)
                ? NSColor.white.withAlphaComponent(0.82)
                : NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.88)).cgColor
            root.addSublayer(dot)

            let destination = CGPoint(x: origin.x + vector.x, y: origin.y + vector.y)

            let position = CABasicAnimation(keyPath: "position")
            position.fromValue = NSValue(point: origin)
            position.toValue = NSValue(point: destination)

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.95
            opacity.toValue = 0

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1
            scale.toValue = 0.25

            let group = CAAnimationGroup()
            group.animations = [position, opacity, scale]
            group.duration = Self.duration * (0.78 + Double(index % 4) * 0.06)
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            dot.add(group, forKey: "particleDismissal")
        }
    }
}
