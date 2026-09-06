import AppKit
import QuartzCore

/// GPU-driven one-shot window dusting.
///
/// The reference effect is not a burst of a few independent fragments. It is a
/// progressive erosion front followed by a dense field of very small dust.
/// CAEmitterLayer lets the compositor own hundreds of short-lived motes without
/// creating hundreds of AppKit views/layers or running a display-link loop.
final class WindowDismissalEffectView: NSView {
    private static let duration: CFTimeInterval = 1.02
    private static let emissionWindow: CFTimeInterval = 0.42
    private static let nominalParticleBirthRate: Float = 885
    private static let emitterCellCount = 4

    static var animationDurationForTesting: CFTimeInterval { duration }
    static var emissionWindowForTesting: CFTimeInterval { emissionWindow }
    static var nominalParticleBirthRateForTesting: Float { nominalParticleBirthRate }
    static var emitterCellCountForTesting: Int { emitterCellCount }

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
        animateErosionEdge()
        animateSurfaceRelease()
        emitDustField()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.16) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    /// The image disappears behind a directional soft edge, not as one fading
    /// rectangle. The edge starts on the tile's outside and moves inward.
    private func animateErosion() {
        guard let snapshotLayer = snapshotView.layer else { return }
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let movesRight = driftDirection.dx >= 0

        let mask = CAGradientLayer()
        mask.frame = CGRect(x: -width * 0.55,
                            y: -height * 0.10,
                            width: width * 1.65,
                            height: height * 1.20)
        mask.colors = [
            NSColor.clear.cgColor,
            NSColor.clear.cgColor,
            NSColor.white.cgColor,
            NSColor.white.cgColor,
        ]
        mask.locations = [0, 0.18, 0.38, 1]
        mask.startPoint = movesRight ? CGPoint(x: 0, y: 0.52) : CGPoint(x: 1, y: 0.48)
        mask.endPoint = movesRight ? CGPoint(x: 1, y: 0.48) : CGPoint(x: 0, y: 0.52)
        snapshotLayer.mask = mask

        let start = mask.position
        let deltaX = width * (movesRight ? 1.34 : -1.34)
        let end = CGPoint(x: start.x + deltaX,
                          y: start.y + height * 0.035 * driftDirection.dy)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.position = end
        CATransaction.commit()

        let sweep = CAKeyframeAnimation(keyPath: "position")
        sweep.values = [
            NSValue(point: start),
            NSValue(point: CGPoint(x: start.x + deltaX * 0.18,
                                   y: start.y)),
            NSValue(point: CGPoint(x: start.x + deltaX * 0.56,
                                   y: start.y + (end.y - start.y) * 0.46)),
            NSValue(point: CGPoint(x: start.x + deltaX * 0.86,
                                   y: start.y + (end.y - start.y) * 0.82)),
            NSValue(point: end),
        ]
        sweep.keyTimes = [0, 0.12, 0.42, 0.73, 1]
        sweep.duration = Self.duration * 0.78
        sweep.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.24, 0.76, 0.28, 1),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut),
        ]
        sweep.isRemovedOnCompletion = false
        sweep.fillMode = .forwards
        mask.add(sweep, forKey: "erosionSweep")

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [1.0, 0.99, 0.88, 0.54, 0.06]
        opacity.keyTimes = [0, 0.14, 0.42, 0.72, 1]

        let drift = CAKeyframeAnimation(keyPath: "transform")
        drift.values = [
            CATransform3DIdentity,
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: driftDirection.dx * 2,
                                  y: driftDirection.dy * 1.5)),
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: driftDirection.dx * 8,
                                  y: driftDirection.dy * 11)
                    .scaledBy(x: 0.978, y: 0.978)),
        ]
        drift.keyTimes = [0, 0.36, 1]

        let group = CAAnimationGroup()
        group.animations = [opacity, drift]
        group.duration = Self.duration * 0.82
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.74, 0.18, 1)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        snapshotLayer.add(group, forKey: "surfaceDusting")
    }

    /// A narrow light band travels with the erosion front. This is what gives
    /// the dissolve its "energized edge" instead of looking like plain opacity.
    private func animateErosionEdge() {
        guard let root = layer else { return }
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let movesRight = driftDirection.dx >= 0

        let glow = CAGradientLayer()
        glow.frame = CGRect(x: movesRight ? -34 : width,
                            y: -height * 0.06,
                            width: 38,
                            height: height * 1.12)
        glow.colors = [
            NSColor.clear.cgColor,
            NSColor.white.withAlphaComponent(0.16).cgColor,
            NSColor.white.withAlphaComponent(0.62).cgColor,
            NSColor.controlAccentColor.withAlphaComponent(0.30).cgColor,
            NSColor.clear.cgColor,
        ]
        glow.locations = [0, 0.25, 0.48, 0.68, 1]
        glow.startPoint = CGPoint(x: 0, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 0.5)
        glow.opacity = 0
        root.addSublayer(glow)

        let travel = width + 72
        let position = CABasicAnimation(keyPath: "transform.translation.x")
        position.fromValue = 0
        position.toValue = movesRight ? travel : -travel

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.74, 0.55, 0.0]
        opacity.keyTimes = [0, 0.10, 0.72, 1]

        let group = CAAnimationGroup()
        group.animations = [position, opacity]
        group.duration = Self.duration * 0.74
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.70, 0.18, 1)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        glow.add(group, forKey: "erosionEdge")
    }

    private func animateSurfaceRelease() {
        guard let root = layer else { return }
        let flash = CAShapeLayer()
        flash.frame = bounds
        flash.path = CGPath(
            roundedRect: bounds.insetBy(dx: 2.5, dy: 2.5),
            cornerWidth: DesignTokens.cardCornerRadius + 5,
            cornerHeight: DesignTokens.cardCornerRadius + 5,
            transform: nil)
        flash.fillColor = NSColor.clear.cgColor
        flash.strokeColor = NSColor.white.withAlphaComponent(0.36).cgColor
        flash.lineWidth = 0.9
        flash.opacity = 0
        root.addSublayer(flash)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.42, 0.16, 0.0]
        opacity.keyTimes = [0, 0.08, 0.36, 1]

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.995
        scale.toValue = 1.025

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = Self.duration * 0.42
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        flash.add(group, forKey: "surfaceRelease")
    }

    /// Dense micro-particles are emitted by the compositor, not individually
    /// allocated CALayers. At the configured birth rate the 0.42 s emission
    /// window produces roughly 370 motes across four size classes.
    private func emitDustField() {
        guard let root = layer,
              let particle = Self.softParticleImage else { return }

        let emitter = CAEmitterLayer()
        emitter.frame = bounds.insetBy(dx: -18, dy: -18)
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        emitter.emitterSize = CGSize(width: bounds.width * 0.92,
                                     height: bounds.height * 0.88)
        emitter.emitterShape = .rectangle
        emitter.emitterMode = .surface
        emitter.renderMode = .unordered
        emitter.masksToBounds = false

        let angle = atan2(driftDirection.dy, driftDirection.dx)

        let micro = makeCell(
            image: particle,
            birthRate: 500,
            lifetime: 0.82,
            velocity: 66,
            velocityRange: 34,
            scale: 0.075,
            scaleRange: 0.055,
            alphaSpeed: -1.05,
            spin: 3.4,
            color: NSColor.white.withAlphaComponent(0.76),
            angle: angle,
            spread: .pi * 0.34)

        let dust = makeCell(
            image: particle,
            birthRate: 245,
            lifetime: 0.96,
            velocity: 78,
            velocityRange: 42,
            scale: 0.135,
            scaleRange: 0.09,
            alphaSpeed: -0.88,
            spin: 4.8,
            color: NSColor.secondaryLabelColor.withAlphaComponent(0.68),
            angle: angle,
            spread: .pi * 0.42)

        let glint = makeCell(
            image: particle,
            birthRate: 85,
            lifetime: 0.72,
            velocity: 58,
            velocityRange: 28,
            scale: 0.17,
            scaleRange: 0.08,
            alphaSpeed: -1.18,
            spin: 2.2,
            color: NSColor.controlAccentColor.withAlphaComponent(0.46),
            angle: angle,
            spread: .pi * 0.28)

        // Sparse larger, low-alpha motes form the soft dust cloud visible
        // behind the sharper micro-particles in the reference dissolve.
        let haze = makeCell(
            image: particle,
            birthRate: 55,
            lifetime: 1.12,
            velocity: 44,
            velocityRange: 22,
            scale: 0.46,
            scaleRange: 0.18,
            alphaSpeed: -0.34,
            spin: 1.4,
            color: NSColor.secondaryLabelColor.withAlphaComponent(0.18),
            angle: angle,
            spread: .pi * 0.48)

        emitter.emitterCells = [micro, dust, glint, haze]
        emitter.birthRate = 0
        root.addSublayer(emitter)

        // The model value is zero so emission cannot accidentally persist after
        // the animation is removed. Only the presentation layer emits.
        let gate = CAKeyframeAnimation(keyPath: "birthRate")
        gate.values = [0.0, 1.0, 1.0, 0.0]
        gate.keyTimes = [0, 0.04, 0.82, 1]
        gate.duration = Self.emissionWindow
        gate.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
        ]
        emitter.add(gate, forKey: "dustGate")
    }

    private func makeCell(image: CGImage,
                          birthRate: Float,
                          lifetime: Float,
                          velocity: CGFloat,
                          velocityRange: CGFloat,
                          scale: CGFloat,
                          scaleRange: CGFloat,
                          alphaSpeed: Float,
                          spin: CGFloat,
                          color: NSColor,
                          angle: CGFloat,
                          spread: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.birthRate = birthRate
        cell.lifetime = lifetime
        cell.lifetimeRange = lifetime * 0.16
        cell.velocity = velocity
        cell.velocityRange = velocityRange
        cell.emissionLongitude = angle
        cell.emissionRange = spread
        cell.xAcceleration = driftDirection.dx * 18
        cell.yAcceleration = driftDirection.dy * 22
        cell.scale = scale
        cell.scaleRange = scaleRange
        cell.scaleSpeed = -scale * 0.34
        cell.alphaSpeed = alphaSpeed
        cell.spin = spin
        cell.spinRange = spin * 0.76
        cell.color = color.cgColor
        cell.redRange = 0.10
        cell.greenRange = 0.10
        cell.blueRange = 0.10
        return cell
    }

    private static let softParticleImage: CGImage? = {
        let dimension = 16
        let bytesPerPixel = 4
        let bytesPerRow = dimension * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let center = CGPoint(x: CGFloat(dimension) / 2,
                             y: CGFloat(dimension) / 2)
        let colors = [
            NSColor.white.withAlphaComponent(1.0).cgColor,
            NSColor.white.withAlphaComponent(0.72).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0.0, 0.46, 1.0]
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: colors,
                                        locations: locations)
        else { return nil }
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: CGFloat(dimension) / 2,
            options: [])
        return context.makeImage()
    }()
}
