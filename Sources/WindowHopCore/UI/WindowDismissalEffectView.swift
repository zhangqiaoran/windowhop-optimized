import AppKit
import QuartzCore

/// One-shot, compositor-driven "true dissolve" for a closing switcher card.
///
/// v3.3 separates two jobs:
/// 1. a cached sequence of irregular alpha masks actually removes pixels from
///    the captured card, so the thumbnail itself breaks apart instead of merely
///    sitting underneath a particle effect;
/// 2. a narrow moving CAEmitterLayer follows that erosion front and sheds dust.
///
/// The mask atlas is deterministic, low-resolution, and lazily cached. A close
/// therefore performs no image filtering and no per-frame CPU simulation.
final class WindowDismissalEffectView: NSView {
    private static let duration: CFTimeInterval = 1.02
    private static let erosionDuration: CFTimeInterval = 0.88
    private static let emissionWindow: CFTimeInterval = 0.74
    private static let reflowStartFraction: CFTimeInterval = 0.80
    private static let nominalParticleBirthRate: Float = 640
    private static let emitterCellCount = 4
    private static let erosionMaskFrameCount = 36
    private static let erosionMaskWidth = 112
    private static let erosionMaskHeight = 70

    static var listReflowDelay: CFTimeInterval {
        duration * reflowStartFraction
    }

    static var animationDurationForTesting: CFTimeInterval { duration }
    static var emissionWindowForTesting: CFTimeInterval { emissionWindow }
    static var reflowStartFractionForTesting: CFTimeInterval { reflowStartFraction }
    static var listReflowDelayForTesting: CFTimeInterval { listReflowDelay }
    static var nominalParticleBirthRateForTesting: Float { nominalParticleBirthRate }
    static var emitterCellCountForTesting: Int { emitterCellCount }
    static var erosionMaskFrameCountForTesting: Int { erosionMaskFrameCount }
    static var usesFragmentMaskForTesting: Bool { true }

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

        animateFragmentErosion()
        animateErosionEdge()
        animateSurfaceRelease()
        emitDustFromErosionFront()

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.duration + 0.18) { [weak self] in
            self?.removeFromSuperview()
        }
    }

    /// Uses real alpha-mask frames rather than a moving soft gradient. Fine and
    /// coarse deterministic noise make holes appear ahead of the main front,
    /// grow into islands, and finally consume the whole snapshot.
    private func animateFragmentErosion() {
        guard let snapshotLayer = snapshotView.layer else { return }
        let movesRight = driftDirection.dx >= 0
        let frames = Self.fragmentMasks(movesRight: movesRight)
        guard let first = frames.first, let last = frames.last else { return }

        let maskLayer = CALayer()
        maskLayer.frame = snapshotLayer.bounds
        maskLayer.contentsGravity = .resize
        maskLayer.magnificationFilter = .linear
        maskLayer.minificationFilter = .linear
        maskLayer.contents = last
        snapshotLayer.mask = maskLayer

        let contents = CAKeyframeAnimation(keyPath: "contents")
        contents.values = frames.map { $0 as Any }
        contents.keyTimes = (0..<frames.count).map {
            NSNumber(value: Double($0) / Double(max(1, frames.count - 1)))
        }
        contents.calculationMode = .discrete
        contents.duration = Self.erosionDuration
        contents.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.72, 0.20, 1)
        contents.isRemovedOnCompletion = false
        contents.fillMode = .forwards
        maskLayer.contents = first
        maskLayer.add(contents, forKey: "fragmentErosion")

        // Keep the card spatially stable while its pixels disappear. A tiny
        // optical drift is enough to avoid a pasted-on look without competing
        // with the later panel reflow.
        let drift = CAKeyframeAnimation(keyPath: "transform")
        drift.values = [
            CATransform3DIdentity,
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: driftDirection.dx * 1.5,
                                  y: driftDirection.dy * 1.0)),
            CATransform3DMakeAffineTransform(
                CGAffineTransform(translationX: driftDirection.dx * 4,
                                  y: driftDirection.dy * 5)
                    .scaledBy(x: 0.992, y: 0.992)),
        ]
        drift.keyTimes = [0, 0.52, 1]
        drift.duration = Self.erosionDuration
        drift.timingFunction = CAMediaTimingFunction(name: .easeOut)
        drift.isRemovedOnCompletion = false
        drift.fillMode = .forwards
        snapshotLayer.add(drift, forKey: "erosionDrift")
    }

    private func animateErosionEdge() {
        guard let root = layer else { return }
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let movesRight = driftDirection.dx >= 0

        let glow = CAGradientLayer()
        glow.frame = CGRect(x: movesRight ? -32 : width - 6,
                            y: -height * 0.06,
                            width: 38,
                            height: height * 1.12)
        glow.colors = [
            NSColor.clear.cgColor,
            NSColor.white.withAlphaComponent(0.10).cgColor,
            NSColor.white.withAlphaComponent(0.70).cgColor,
            NSColor.systemBlue.withAlphaComponent(0.26).cgColor,
            NSColor.clear.cgColor,
        ]
        glow.locations = [0, 0.24, 0.48, 0.68, 1]
        glow.startPoint = CGPoint(x: 0, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 0.5)
        glow.opacity = 0
        root.addSublayer(glow)

        let travel = width + 70
        let position = CABasicAnimation(keyPath: "transform.translation.x")
        position.fromValue = 0
        position.toValue = movesRight ? travel : -travel

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.72, 0.58, 0.18, 0.0]
        opacity.keyTimes = [0, 0.08, 0.56, 0.86, 1]

        let group = CAAnimationGroup()
        group.animations = [position, opacity]
        group.duration = Self.erosionDuration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.70, 0.20, 1)
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
        flash.strokeColor = NSColor.white.withAlphaComponent(0.30).cgColor
        flash.lineWidth = 0.8
        flash.opacity = 0
        root.addSublayer(flash)

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = [0.0, 0.34, 0.12, 0.0]
        opacity.keyTimes = [0, 0.08, 0.36, 1]

        let group = CAAnimationGroup()
        group.animations = [opacity]
        group.duration = Self.duration * 0.38
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        flash.add(group, forKey: "surfaceRelease")
    }

    /// The emitter is a narrow moving strip, not a full-card rectangle. Dust is
    /// therefore born where pixels are currently being removed, which visually
    /// connects the fragments to the dissolving thumbnail.
    private func emitDustFromErosionFront() {
        guard let root = layer,
              let particle = Self.softParticleImage else { return }

        let emitter = CAEmitterLayer()
        emitter.frame = bounds.insetBy(dx: -24, dy: -20)
        let movesRight = driftDirection.dx >= 0
        let start = CGPoint(
            x: movesRight ? 18 : emitter.bounds.width - 18,
            y: emitter.bounds.midY)
        let end = CGPoint(
            x: movesRight ? emitter.bounds.width - 18 : 18,
            y: emitter.bounds.midY + driftDirection.dy * 8)
        emitter.emitterPosition = end
        emitter.emitterSize = CGSize(width: 16, height: bounds.height * 0.92)
        emitter.emitterShape = .rectangle
        emitter.emitterMode = .surface
        emitter.renderMode = .unordered
        emitter.masksToBounds = false

        let angle = atan2(driftDirection.dy, driftDirection.dx)
        let micro = makeCell(
            image: particle, birthRate: 360, lifetime: 0.86,
            velocity: 72, velocityRange: 38, scale: 0.070, scaleRange: 0.052,
            alphaSpeed: -1.00, spin: 3.8,
            color: NSColor.white.withAlphaComponent(0.74),
            angle: angle, spread: .pi * 0.34)
        let dust = makeCell(
            image: particle, birthRate: 190, lifetime: 1.02,
            velocity: 84, velocityRange: 46, scale: 0.13, scaleRange: 0.09,
            alphaSpeed: -0.82, spin: 5.0,
            color: NSColor.secondaryLabelColor.withAlphaComponent(0.66),
            angle: angle, spread: .pi * 0.42)
        let glint = makeCell(
            image: particle, birthRate: 55, lifetime: 0.72,
            velocity: 62, velocityRange: 30, scale: 0.16, scaleRange: 0.07,
            alphaSpeed: -1.16, spin: 2.4,
            color: NSColor.systemBlue.withAlphaComponent(0.38),
            angle: angle, spread: .pi * 0.26)
        let haze = makeCell(
            image: particle, birthRate: 35, lifetime: 1.18,
            velocity: 46, velocityRange: 24, scale: 0.44, scaleRange: 0.18,
            alphaSpeed: -0.30, spin: 1.4,
            color: NSColor.secondaryLabelColor.withAlphaComponent(0.16),
            angle: angle, spread: .pi * 0.48)

        emitter.emitterCells = [micro, dust, glint, haze]
        emitter.birthRate = 0
        root.addSublayer(emitter)

        let front = CAKeyframeAnimation(keyPath: "emitterPosition")
        front.values = [
            NSValue(point: start),
            NSValue(point: CGPoint(x: start.x + (end.x - start.x) * 0.28,
                                   y: start.y + (end.y - start.y) * 0.12)),
            NSValue(point: CGPoint(x: start.x + (end.x - start.x) * 0.68,
                                   y: start.y + (end.y - start.y) * 0.58)),
            NSValue(point: end),
        ]
        front.keyTimes = [0, 0.24, 0.64, 1]
        front.duration = Self.erosionDuration
        front.timingFunctions = [
            CAMediaTimingFunction(controlPoints: 0.20, 0.70, 0.22, 1),
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeOut),
        ]
        front.isRemovedOnCompletion = false
        front.fillMode = .forwards
        emitter.add(front, forKey: "erosionFront")

        let gate = CAKeyframeAnimation(keyPath: "birthRate")
        gate.values = [0.0, 1.0, 1.0, 0.46, 0.0]
        gate.keyTimes = [0, 0.03, 0.70, 0.90, 1]
        gate.duration = Self.emissionWindow
        gate.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .linear),
            CAMediaTimingFunction(name: .easeOut),
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

    // MARK: - Cached erosion atlas

    private static func fragmentMasks(movesRight: Bool) -> [CGImage] {
        movesRight ? rightwardFragmentMasks : leftwardFragmentMasks
    }

    private static let rightwardFragmentMasks: [CGImage] = {
        makeFragmentMasks(movesRight: true)
    }()

    private static let leftwardFragmentMasks: [CGImage] = {
        makeFragmentMasks(movesRight: false)
    }()

    private static func makeFragmentMasks(movesRight: Bool) -> [CGImage] {
        (0..<erosionMaskFrameCount).compactMap { frame in
            makeFragmentMask(frame: frame, movesRight: movesRight)
        }
    }

    private static func makeFragmentMask(frame: Int, movesRight: Bool) -> CGImage? {
        let width = erosionMaskWidth
        let height = erosionMaskHeight
        let last = max(1, erosionMaskFrameCount - 1)
        let normalized = CGFloat(frame) / CGFloat(last)
        let progress = -0.10 + normalized * 1.22
        let feather: CGFloat = 0.045

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let alpha: UInt8
                if frame == 0 {
                    alpha = 255
                } else if frame == last {
                    alpha = 0
                } else {
                    let xn = CGFloat(x) / CGFloat(max(1, width - 1))
                    let yn = CGFloat(y) / CGFloat(max(1, height - 1))
                    let direction = movesRight ? xn : (1 - xn)
                    let fine = hashNoise(x, y)
                    let cluster = hashNoise(x / 6 + 29, y / 5 + 71)
                    let verticalWave = CGFloat(sin(Double(yn * 12.0))) * 0.025
                    let threshold = direction
                        + (fine - 0.5) * 0.34
                        + (cluster - 0.5) * 0.22
                        + verticalWave
                    let t = max(0, min(1, (threshold - progress + feather) / (feather * 2)))
                    let smooth = t * t * (3 - 2 * t)
                    alpha = UInt8((smooth * 255).rounded())
                }

                let offset = (y * width + x) * 4
                pixels[offset] = alpha
                pixels[offset + 1] = alpha
                pixels[offset + 2] = alpha
                pixels[offset + 3] = alpha
            }
        }

        let data = Data(pixels) as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent)
    }

    private static func hashNoise(_ x: Int, _ y: Int) -> CGFloat {
        var value = UInt64(x) &* 0x9E37_79B1_85EB_CA87
        value ^= UInt64(y) &* 0xC2B2_AE3D_27D4_EB4F
        value ^= value >> 33
        value &*= 0xFF51_AFD7_ED55_8CCD
        value ^= value >> 33
        return CGFloat(value & 0xFFFF) / CGFloat(0xFFFF)
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
