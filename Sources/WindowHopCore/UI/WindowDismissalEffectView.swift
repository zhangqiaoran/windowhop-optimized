import AppKit
import QuartzCore

/// One-shot window-close dusting effect with a fixed compositor budget.
///
/// v3.0 uses an R2 low-discrepancy surface distribution instead of random
/// sampling, so every close covers the whole card evenly without storage,
/// sorting, or per-frame CPU work. A moving gradient mask erodes the snapshot
/// while 56 bounded particles peel away along cubic wind paths.
///
/// The effect is fully Core Animation driven after `play()`: no display link,
/// no repeating timer, and no idle cost.
final class WindowDismissalEffectView: NSView {
    private static let particleCount = 56
    private static let duration: CFTimeInterval = 0.62
    private static let emissionWindow: CFTimeInterval = 0.24

    static var particleCountForTesting: Int { particleCount }
    static var animationDurationForTesting: CFTimeInterval { duration }
    static var emissionWindowForTesting: CFTimeInterval { emissionWindow }

    private let snapshotView = NSImageView()
    private let driftDirection: CGVector

    init(frame frameRect: NSRect,
         snapshot: NSImage?,
         driftDirection: CGVector = CGVector(dx: 0.55, dy: 1)) {
        let length = max(0.001, hypot(driftDirection.dx, driftDirection.dy))
        self.driftDirection = CGVector(dx: driftDirection.dx / length,
                                       dy: driftDirection.dy / length)
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

        animateErosion()
        animateGlassRelease()
        emitDust()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.10) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    /// A soft mask sweeps across the captured tile, so the card erodes instead
    /// of disappearing as one rigid rectangle.
    private func animateErosion() {
        guard let snapshotLayer = snapshotView.layer else { return }
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)

        let mask = CAGradientLayer()
        mask.frame = CGRect(x: -width * 0.50,
                            y: -height * 0.08,
                            width: width * 1.55,
                            height: height * 1.16)
        mask.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            NSColor.white.cgColor,
            NSColor.white.cgColor,
        ]
        mask.locations = [0, 0.15, 0.34, 1]
        mask.startPoint = CGPoint(x: 0, y: 0.58)
        mask.endPoint = CGPoint(x: 1, y: 0.42)
        snapshotLayer.mask = mask

        let start = mask.position
        let end = CGPoint(
            x: start.x + width * (1.30 + 0.12 * abs(driftDirection.dx)),
            y: start.y + height * 0.08 * driftDirection.dy)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.position = end
        CATransaction.commit()

        let sweep = CAKeyframeAnimation(keyPath: "position")
        sweep.values = [
            NSValue(point: start),
            NSValue(point: CGPoint(
                x: start.x + (end.x - start.x) * 0.36,
                y: start.y + (end.y - start.y) * 0.20)),
            NSValue(point: CGPoint(
                x: start.x + (end.x - start.x) * 0.72,
                y: start.y + (end.y - start.y) * 0.68)),
            NSValue(point: end),
        ]
        sweep.keyTimes = [0, 0.28, 0.68, 1]
        sweep.duration = Self.duration * 0.78
        sweep.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.20, 0.78, 0.20, 1),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut),
        ]
        sweep.isRemovedOnCompletion = false
        sweep.fillMode = .forwards
        mask.add(sweep, forKey: "erosionSweep")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.98, 0.70, 0.10]
        opacity.keyTimes = [0, 0.28, 0.72, 1]

        let transform = CAKeyframeAnimation(keyPath: "transform")
        transform.values = [
            CATransform3DIdentity,
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: driftDirection.dx * 1.5,
                                  y: driftDirection.dy * 1.5)),
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: driftDirection.dx * 7,
                                  y: driftDirection.dy * 9)
                    .scaledBy(x: 0.965, y: 0.965)),
        ]
        transform.keyTimes = [0, 0.32, 1]

        let group = CAAnimationGroup()
        group.animations = [opacity, transform]
        group.duration = Self.duration * 0.82
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.82, 0.20, 1)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        snapshotLayer.add(group, forKey: "snapshotDusting")
    }

    private func animateGlassRelease() {
        guard let root = layer else { return }

        let flash = CAShapeLayer()
        let rect = bounds.insetBy(dx: 3, dy: 3)
        flash.frame = bounds
        flash.path = CGPath(
            roundedRect: rect,
            cornerWidth: DesignTokens.cardCornerRadius + 5,
            cornerHeight: DesignTokens.cardCornerRadius + 5,
            transform: nil)
        flash.fillColor = NSColor.clear.cgColor
        flash.strokeColor = NSColor.keyboardFocusIndicatorColor
            .withAlphaComponent(0.60).cgColor
        flash.lineWidth = 1.2
        flash.opacity = 0
        root.addSublayer(flash)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.72, 0.28, 0.0]
        opacity.keyTimes = [0, 0.10, 0.46, 1]

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.99
        scale.toValue = 1.055

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = Self.duration * 0.58
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        flash.add(group, forKey: "glassRelease")
    }

    private func emitDust() {
        guard let root = layer else { return }
        let baseTime = root.convertTime(CACurrentMediaTime(), from: nil)

        // R2 sequence based on the plastic constant: deterministic quasi-random
        // coverage with much less clumping than ordinary pseudo-random points.
        let plastic = 1.324_717_957_244_746
        let alpha1 = 1 / plastic
        let alpha2 = 1 / (plastic * plastic)

        for index in 0..<Self.particleCount {
            let i = Double(index + 1)
            let xUnit = fractional(0.5 + alpha1 * i)
            let yUnit = fractional(0.5 + alpha2 * i)

            let origin = CGPoint(
                x: bounds.width * (0.045 + 0.91 * xUnit),
                y: bounds.height * (0.055 + 0.89 * yUnit))

            let wobble = 0.055 * sin(i * 2.399_963)
            let phase = min(1, max(0,
                0.76 * xUnit + 0.24 * (1 - yUnit) + wobble))
            let localBegin = phase * Self.emissionWindow

            let spread = fractional(i * 0.618_033_988_75)
            let tangent = CGVector(dx: -driftDirection.dy,
                                   dy: driftDirection.dx)
            let sideways = (spread - 0.5) * 76
            let travel = 58 + 78 * fractional(i * 0.414_213_562)
            let lift = 18 + 34 * fractional(i * 0.707_106_781)

            let destination = CGPoint(
                x: origin.x + driftDirection.dx * travel + tangent.dx * sideways,
                y: origin.y + driftDirection.dy * (travel * 0.72 + lift)
                    + tangent.dy * sideways)

            let control1 = CGPoint(
                x: origin.x + driftDirection.dx * travel * 0.24
                    + tangent.dx * sideways * 0.34,
                y: origin.y + driftDirection.dy * travel * 0.22
                    + tangent.dy * sideways * 0.34 + 5)
            let control2 = CGPoint(
                x: origin.x + driftDirection.dx * travel * 0.70
                    + tangent.dx * sideways * 0.82,
                y: origin.y + driftDirection.dy * (travel * 0.55 + lift * 0.68)
                    + tangent.dy * sideways * 0.82)

            let width = CGFloat(1.4 + 4.4 * fractional(i * 0.271_828_183))
            let height = CGFloat(1.0 + 3.8 * fractional(i * 0.367_879_441))
            let mote = CALayer()
            mote.bounds = CGRect(x: 0, y: 0, width: width, height: height)
            mote.position = origin
            mote.cornerRadius = min(width, height)
                * (index.isMultiple(of: 4) ? 0.5 : 0.22)

            let color: NSColor
            switch index % 9 {
            case 0:
                color = NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.78)
            case 1, 2:
                color = NSColor.labelColor.withAlphaComponent(0.68)
            default:
                color = NSColor.secondaryLabelColor.withAlphaComponent(0.78)
            }
            mote.backgroundColor = color.cgColor
            if index.isMultiple(of: 5) {
                mote.shadowColor = color.withAlphaComponent(0.28).cgColor
                mote.shadowOpacity = 1
                mote.shadowRadius = 2.2
                mote.shadowOffset = .zero
            }
            root.addSublayer(mote)

            let path = CGMutablePath()
            path.move(to: origin)
            path.addCurve(to: destination, control1: control1, control2: control2)
            let position = CAKeyframeAnimation(keyPath: "position")
            position.path = path
            position.calculationMode = .paced

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 0.92, 0.76, 0.30, 0.0]
            opacity.keyTimes = [0, 0.08, 0.34, 0.74, 1]

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.35, 1.12, 0.88, 0.12]
            scale.keyTimes = [0, 0.16, 0.52, 1]

            let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
            rotation.fromValue = -0.20
            rotation.toValue = (index.isMultiple(of: 2) ? 1 : -1)
                * (1.2 + 2.6 * spread)

            let group = CAAnimationGroup()
            group.animations = [position, opacity, scale, rotation]
            group.duration = Self.duration - localBegin
            group.beginTime = baseTime + localBegin
            group.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.76, 0.18, 1)
            group.isRemovedOnCompletion = false
            group.fillMode = .forwards
            mote.add(group, forKey: "dust")
        }
    }

    private func fractional(_ value: Double) -> Double {
        value - floor(value)
    }
}
