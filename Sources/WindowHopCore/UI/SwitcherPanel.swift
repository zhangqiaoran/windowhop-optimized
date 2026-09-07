import AppKit

/// NSView normally ignores a child's descendants outside that child's bounds.
/// Close is intentionally centered on the canvas corner, so the document view
/// explicitly forwards hits within its clip-safe overlay gutter.
private final class SwitcherTilesContainerView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        for case let tile as SwitcherTileView in subviews.reversed() where !tile.isHidden {
            if let hit = tile.closeControlHitTest(convert(point, to: tile)) {
                return hit
            }
        }
        return super.hitTest(point)
    }
}

/// One shared transparent focus ring follows the selected window.
///
/// Selection no longer places another frosted material over the window preview:
/// the preview stays visually untouched and the selected state is communicated
/// only by a semantic macOS blue ring + a restrained blue glow. The moving ring
/// remains constant-cost regardless of window count.
private final class SelectionLensView: NSView {
    init(rasterizable _: Bool) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.selectionLensCornerRadius
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = NSColor.clear.cgColor
        setAccessibilityElement(false)
        refreshAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: DesignTokens.selectionLensCornerRadius,
            cornerHeight: DesignTokens.selectionLensCornerRadius,
            transform: nil)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    func applyLiquidGlass(transparencyPercent _: Double) {
        // Kept as the panel appearance hook: selection is intentionally
        // independent of glass density and always remains transparent.
        refreshAppearance()
    }

    private func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.clear.cgColor
            layer?.borderColor = DesignTokens.selectionLensStroke.cgColor
            layer?.borderWidth = DesignTokens.selectionLensBorderWidth
            layer?.shadowColor = DesignTokens.selectionLensGlow.cgColor
            layer?.shadowOpacity = 1
            layer?.shadowRadius = DesignTokens.selectionLensGlowRadius
            layer?.shadowOffset = .zero
        }
    }

    var usesLiquidGlassMaterialForTesting: Bool { false }
    var densityAlphaForTesting: CGFloat { 0 }
    var borderWidthForTesting: CGFloat { layer?.borderWidth ?? 0 }
    var borderColorForTesting: NSColor? {
        guard let color = layer?.borderColor else { return nil }
        return NSColor(cgColor: color)
    }
}

private final class SwitcherPanelActionButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private final class SwitcherPanelHostView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private(set) var isPointerInside = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        return super.hitTest(point) ?? self
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        setPointerInside(true)
    }

    override func mouseExited(with event: NSEvent) {
        setPointerInside(false)
    }

    func refreshPointerLocation() {
        guard let window else {
            setPointerInside(false)
            return
        }
        setPointerInside(bounds.contains(convert(
            window.mouseLocationOutsideOfEventStream, from: nil)))
    }

    func setPointerInside(_ value: Bool) {
        guard isPointerInside != value else { return }
        isPointerInside = value
        onHoverChanged?(value)
    }
}

public enum SwitcherPresentationMode: Equatable {
    case cycling
    case persistent
}

/// The switcher: a compact, non-activating panel centered on the active display.
/// A fixed-size grid of tiles — one per window — in either App Icons or Window
/// Previews appearance. No search or theme options. System
/// materials and semantic colors keep it correct in Light/Dark Mode, Increase
/// Contrast, and Reduce Transparency.
public final class SwitcherPanel: NSPanel, NSTextFieldDelegate {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { false }
    public var onItemClicked: ((Int) -> Void)?
    /// Hover close control on a tile; routes through the same direct close as Delete.
    public var onItemCloseRequested: ((Int) -> Void)?
    /// The panel-chrome gear control (and ⌘, while a session is open).
    public var onSettingsRequested: (() -> Void)?
    /// Pins the current held session into persistent mode.
    public var onPinRequested: (() -> Void)?
    /// Search text changed. The controller owns filtering so keyboard/mouse
    /// indices remain consistent with the visible list.
    public var onSearchQueryChanged: ((String) -> Void)?
    /// While the search editor is active, global key interception yields to
    /// AppKit so normal text editing is zero-friction.
    public var onSearchEditingChanged: ((Bool) -> Void)?
    /// One panel-level action when all preview capture is permission-blocked.
    public var onPreviewPermissionRequested: (() -> Void)?

    /// Transparent overflow host. The visible panel occupies only
    /// `panelBackgroundView`; global controls may extend into the host without
    /// changing the panel's internal layout.
    private let hostView = SwitcherPanelHostView()
    private var panelBackgroundView: NSView!
    /// Root rendering group. On macOS 26+ this is NSGlassEffectContainerView;
    /// older systems point it at the NSVisualEffectView fallback.
    private var glassRootView: NSView!
    private var glassGroupView: NSView?
    private var settingsGlassView: NSView?
    private var usesNativeGlassBackground = false
    /// Fallback-only milk plane. Native macOS 26 glass uses tintColor instead,
    /// keeping all milk/refraction inside the system material.
    private let liquidGlassDensityView = NSView()
    private let liquidGlassDensityMask = CAGradientLayer()
    /// Everything inside the visible panel background (the preview grid).
    private let chromeView = NSView()
    private let scrollView = NSScrollView()
    private let tilesContainer = SwitcherTilesContainerView()
    private let selectionLensView: SelectionLensView
    /// Cached target frames make every selection transition a direct O(1)
    /// indexed lookup. Geometry is rebuilt only when the window list/layout is.
    private var selectionFrames: [NSRect] = []
    private let pinButton = SwitcherPanelActionButton()
    private let searchField = NSSearchField()
    private let emptySearchLabel = NSTextField(labelWithString: "No matching windows")
    private let settingsButton = SwitcherPanelActionButton()
    private let permissionButton = SwitcherPanelActionButton()
    private let expandedPreviewView = ExpandedPreviewView()
    /// Pooled tiles, reconfigured in place; index i shows item i.
    private var tilePool: [SwitcherTileView] = []
    private var visibleTileCount = 0
    private var selectedIndex = 0
    /// Selection painting is updated incrementally during keyboard cycling.
    /// A full O(n) pass is reserved for list rebuilds only.
    private var appliedSelectedIndex = -1
    private var mode = AppearanceMode.appIcons
    private var items: [SwitcherItem] = []
    /// IDs whose original pooled tile is visually hidden while a snapshot
    /// overlay performs true erosion. Geometry remains reserved until the
    /// controller's 80% hand-off removes the item.
    private var dismissalGhostIDs = Set<AnyHashable>()
    /// O(1) delivery lookup for asynchronous preview captures. A session can
    /// deliver many images in quick succession, so repeatedly scanning the list
    /// needlessly scales the UI work with the number of open windows.
    private var itemIndexByID: [AnyHashable: Int] = [:]
    private var expandedPreviewID: AnyHashable?
    private var presentationMode = SwitcherPresentationMode.cycling
    private var isPinned = false
    private var isSearchEditing = false
    private var accessibilityDisplayObserver: NSObjectProtocol?
    private var panelAppearanceObserver: NSObjectProtocol?
    /// Grid geometry of the current layout, for 2D arrow-key navigation.
    public private(set) var columnsPerRow = 1
    /// Monotonic token for interruptible list reflows. Any newer layout update
    /// invalidates an older animation completion so a stale completion can
    /// never snap tiles/window geometry back to an obsolete target.
    private var reflowGeneration: UInt64 = 0

    /// The display this panel draws on. `SwitcherPanelGroup` sets it for every
    /// session; nil falls back to the first screen, which is what the offscreen
    /// render harness uses and what a single-display Mac resolves to anyway.
    /// `NSScreen.main` is deliberately not the fallback: it is documented to
    /// misreport the active screen (see `DisplayRegistry.pointerDisplayID`).
    public var placementScreen: NSScreen?

    /// Grid limits shared by every mirrored panel, so all of them show an
    /// identical grid and `columnsPerRow` stays one authoritative value for
    /// arrow-key navigation. nil means "use this display's own capacity".
    public var sharedColumnLimit: Int?
    public var sharedRowLimit: Int?

    private var layoutScreen: NSScreen? { placementScreen ?? NSScreen.screens.first }

    /// Preview geometry must follow the display the panel is actually drawn on.
    /// Using NSScreen.main here made wide/1x external displays inherit the
    /// primary display's preview aspect, producing visibly wrong canvases.
    private var placementDisplayAspect: CGFloat {
        guard let frame = layoutScreen?.frame, frame.height > 0 else {
            return SwitcherTileView.Metrics.mainDisplayAspect
        }
        return frame.width / frame.height
    }

    /// The preview area a tile offers in Window Previews mode, for capture sizing.
    public static func previewContentSize(displayAspect: CGFloat) -> NSSize {
        let metrics = SwitcherTileView.Metrics.metrics(
            for: .windowPreviews,
            showTabCounts: Preferences.shared.showTabCounts,
            displayAspect: displayAspect)
        return NSSize(width: metrics.tileSize.width - DesignTokens.tileLabelInset * 2,
                      height: metrics.contentHeight)
    }

    public static var previewContentSize: NSSize {
        previewContentSize(displayAspect: SwitcherTileView.Metrics.mainDisplayAspect)
    }

    public static var expandedPreviewContentSize: NSSize {
        NSSize(width: DesignTokens.expandedPreviewMinimumWidth
                        - DesignTokens.expandedPreviewPanelInset * 2,
               height: DesignTokens.expandedPreviewMinimumHeight
                        - DesignTokens.expandedPreviewPanelInset * 2
                        - DesignTokens.expandedPreviewTitleHeight)
    }

    /// `rasterizableBackground` is for the offscreen render harness only: the
    /// macOS 26 glass background cannot be rasterized with cacheDisplay (it
    /// draws empty), so layout renders use the visual-effect fallback instead.
    public init(rasterizableBackground: Bool = false) {
        selectionLensView = SelectionLensView(rasterizable: rasterizableBackground)
        super.init(contentRect: .zero,
                   styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .none
        // A borderless, nonactivating panel must still own mouse clicks. When
        // the user deliberately clicks the switcher, let it become key without
        // activating the application; this prevents the click from falling
        // through to the real window underneath.
        becomesKeyOnlyIfNeeded = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        worksWhenModal = true
        isReleasedWhenClosed = false

        // The native switcher's background. On macOS 26+ that is the system
        // glass material (NSGlassEffectView — blur, vibrancy, and edge
        // treatment come from AppKit, never a hardcoded color); older systems
        // fall back to the closest visual-effect material. Both respect
        // Reduce Transparency and Increase Contrast automatically.
        chromeView.autoresizingMask = []
        chromeView.wantsLayer = true
        chromeView.layer?.backgroundColor = NSColor.clear.cgColor

        // Keep the native Glass strictly in the visual background. Foreground
        // chrome is a sibling above it, not NSGlassEffectView.contentView.
        // This is the same interaction-safe topology used before the regression:
        // Glass can be optically thin while cards/buttons remain ordinary AppKit
        // hit-test targets.
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !rasterizableBackground {
            let glass = NSGlassEffectView()
            glass.style = .clear
            glass.cornerRadius = DesignTokens.panelCornerRadius

            panelBackgroundView = glass
            glassRootView = glass
            usesNativeGlassBackground = true
            hostView.addSubview(glass)
            hostView.addSubview(chromeView, positioned: .above, relativeTo: glass)
        } else {
            let fallback = Self.makeFallbackBackgroundView()
            panelBackgroundView = fallback
            glassRootView = fallback
            hostView.addSubview(fallback)
            hostView.addSubview(chromeView, positioned: .above, relativeTo: fallback)
        }
        #else
        let fallback = Self.makeFallbackBackgroundView()
        panelBackgroundView = fallback
        glassRootView = fallback
        hostView.addSubview(fallback)
        hostView.addSubview(chromeView, positioned: .above, relativeTo: fallback)
        #endif
        contentView = hostView

        liquidGlassDensityView.wantsLayer = true
        liquidGlassDensityView.autoresizingMask = []
        liquidGlassDensityView.setAccessibilityElement(false)
        liquidGlassDensityMask.colors = [
            NSColor.white.cgColor,
            NSColor.white.cgColor,
            NSColor.clear.cgColor,
        ]
        liquidGlassDensityMask.locations = [0, 0.80, 1]
        liquidGlassDensityMask.startPoint = CGPoint(x: 0.5, y: 0)
        liquidGlassDensityMask.endPoint = CGPoint(x: 0.5, y: 1)
        liquidGlassDensityMask.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        liquidGlassDensityView.layer?.mask = liquidGlassDensityMask
        chromeView.addSubview(liquidGlassDensityView)
        applyLiquidGlassAppearance()

        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScrollElasticity = .none
        scrollView.verticalScrollElasticity = .none
        scrollView.documentView = tilesContainer
        chromeView.addSubview(scrollView)

        selectionLensView.isHidden = true
        tilesContainer.addSubview(selectionLensView)

        expandedPreviewView.isHidden = true
        chromeView.addSubview(expandedPreviewView)

        // Contextual pin control. It is a one-way session action: once pinned,
        // modifier release is no longer an activation signal for this session.
        pinButton.image = NSImage(systemSymbolName: "pin",
                                  accessibilityDescription: "Keep switcher open")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(
                pointSize: DesignTokens.chromeButtonSymbolSize * 0.92,
                weight: .semibold))
        pinButton.contentTintColor = .labelColor
        pinButton.isBordered = false
        pinButton.imagePosition = .imageOnly
        pinButton.wantsLayer = true
        pinButton.layer?.cornerRadius = DesignTokens.chromeButtonHitSize / 2
        pinButton.layer?.cornerCurve = .continuous
        pinButton.layer?.backgroundColor = usesNativeGlassBackground
            ? NSColor.clear.cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.42).cgColor
        pinButton.target = self
        pinButton.action = #selector(pinClicked)
        pinButton.toolTip = "Keep switcher open"
        pinButton.setAccessibilityLabel("Keep switcher open")
        pinButton.alphaValue = 0
        pinButton.isEnabled = false
        pinButton.setAccessibilityHidden(true)
        hostView.addSubview(pinButton)

        // Search stays out of the grid and performs no capture work. The
        // controller searches a pre-normalized session index; every keystroke is
        // one linear scan over small cached strings, with no timers/polling.
        searchField.placeholderString = "Search windows…"
        searchField.delegate = self
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        searchField.wantsLayer = true
        searchField.layer?.cornerRadius = 9
        searchField.layer?.cornerCurve = .continuous
        searchField.layer?.backgroundColor = NSColor.controlBackgroundColor
            .withAlphaComponent(usesNativeGlassBackground ? 0.18 : 0.46).cgColor
        searchField.alphaValue = 0
        searchField.isEnabled = false
        searchField.setAccessibilityHidden(true)
        searchField.setAccessibilityLabel("Search windows")
        hostView.addSubview(searchField)

        emptySearchLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptySearchLabel.textColor = .secondaryLabelColor
        emptySearchLabel.alignment = .center
        emptySearchLabel.isHidden = true
        emptySearchLabel.setAccessibilityElement(false)
        chromeView.addSubview(emptySearchLabel)

        // Global panel action: contextual during held cycling, persistent for
        // Open my-alt-tab sessions, and never measured as part of the grid.
        settingsButton.image = NSImage(systemSymbolName: "ellipsis",
                                       accessibilityDescription: "More Options")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(
                pointSize: DesignTokens.chromeButtonSymbolSize,
                weight: .bold))
        settingsButton.contentTintColor = .labelColor
        settingsButton.isBordered = false
        settingsButton.imagePosition = .imageOnly
        settingsButton.wantsLayer = true
        settingsButton.layer?.cornerRadius = DesignTokens.chromeButtonHitSize / 2
        settingsButton.layer?.cornerCurve = .continuous
        settingsButton.layer?.backgroundColor = usesNativeGlassBackground
            ? NSColor.clear.cgColor
            : NSColor.controlBackgroundColor.withAlphaComponent(0.42).cgColor
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        settingsButton.toolTip = "More Options (⌘,)"
        settingsButton.setAccessibilityLabel("More Options")
        settingsButton.alphaValue = 0
        settingsButton.isEnabled = false
        settingsButton.setAccessibilityHidden(true)

        // Keep controls out of NSGlassEffectView.contentView. The button itself
        // is the interaction target; the panel background supplies the Glass.
        hostView.addSubview(settingsButton)

        hostView.onHoverChanged = { [weak self] _ in
            self?.updateSettingsButtonVisibility(animated: true)
        }

        permissionButton.image = NSImage(
            systemSymbolName: "lock.shield.fill",
            accessibilityDescription: "Screen Recording permission required")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(
                pointSize: DesignTokens.chromeButtonSymbolSize * 0.72,
                weight: .semibold)
                .applying(.init(paletteColors: [DesignTokens.overlayGlyphColor,
                                                DesignTokens.overlayCircleColor])))
        permissionButton.isBordered = false
        permissionButton.imagePosition = .imageOnly
        permissionButton.target = self
        permissionButton.action = #selector(permissionClicked)
        permissionButton.toolTip = "Screen Recording permission required — Open System Settings"
        permissionButton.setAccessibilityLabel(
            "Screen Recording permission required. Open System Settings")
        permissionButton.isHidden = true
        hostView.addSubview(permissionButton)

        chromeView.setAccessibilityElement(true)
        chromeView.setAccessibilityRole(.list)
        chromeView.setAccessibilityLabel("my-alt-tab window switcher")

        accessibilityDisplayObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                self?.updateSettingsButtonVisibility(animated: false)
                self?.applyLiquidGlassAppearance()
            }
        panelAppearanceObserver = NotificationCenter.default.addObserver(
            forName: Preferences.panelAppearanceDidChange,
            object: Preferences.shared,
            queue: .main) { [weak self] _ in
                self?.applyLiquidGlassAppearance()
            }

        // Prewarm both dissolve atlases and the emitter texture off the close
        // hot path. This avoids a first-use CPU/GPU resource burst.
        WindowDismissalEffectView.prewarmAssets()

        // pre-warm the tile pool off the first-trigger latency path; tiles beyond
        // this grow the pool once and are then reused forever
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            while self.tilePool.count < 24 {
                let tile = SwitcherTileView()
                tile.isHidden = true
                self.tilesContainer.addSubview(tile)
                self.tilePool.append(tile)
            }
        }
    }

    deinit {
        if let accessibilityDisplayObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityDisplayObserver)
        }
        if let panelAppearanceObserver {
            NotificationCenter.default.removeObserver(panelAppearanceObserver)
        }
    }

    /// `effectIsInteractive` is still a beta AppKit API and is not exposed by
    /// every Xcode 26 SDK even when the running macOS implements it. Resolve it
    /// dynamically so release builds remain SDK-compatible while newer systems
    /// still opt into interactive glass feedback.
    @available(macOS 26.0, *)
    @discardableResult
    private static func enableInteractiveGlassIfAvailable(_ glass: NSGlassEffectView) -> Bool {
        let selector = NSSelectorFromString("setEffectIsInteractive:")
        guard glass.responds(to: selector) else { return false }
        glass.setValue(true, forKey: "effectIsInteractive")
        return true
    }

    /// Liquid Glass transparency is literal: high values make only the
    /// background material optically thinner. Foreground previews, labels and
    /// controls are siblings, so they remain fully opaque and fully interactive.
    private func applyLiquidGlassAppearance() {
        let percent = Preferences.clampedGlassTransparency(
            Preferences.shared.glassTransparencyPercent)
        let liquid = CGFloat(Preferences.liquidGlassFactor(
            forTransparencyPercent: percent))
        let milkFactor = CGFloat(Preferences.liquidGlassMilkFactor(
            forTransparencyPercent: percent))
        let surfaceAlpha = CGFloat(Preferences.liquidGlassSurfaceAlpha(
            forTransparencyPercent: percent))
        let milkAlpha = milkFactor * DesignTokens.glassMaximumMilkAlpha

        panelBackgroundView.alphaValue = surfaceAlpha
        liquidGlassDensityView.layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(milkAlpha).cgColor
        selectionLensView.applyLiquidGlass(transparencyPercent: percent)

        panelBackgroundView.wantsLayer = true
        panelBackgroundView.layer?.cornerRadius = DesignTokens.panelCornerRadius
        panelBackgroundView.layer?.cornerCurve = .continuous

        #if compiler(>=6.2)
        if #available(macOS 26.0, *),
           let glass = panelBackgroundView as? NSGlassEffectView {
            // Clear is AppKit's transparent Glass style. Avoid extra tint and
            // manual borders so wallpaper/window color can read through it.
            glass.style = .clear
            glass.tintColor = nil
            glass.layer?.borderWidth = 0
            return
        }
        #endif

        // Compatibility path for pre-26 systems.
        panelBackgroundView.layer?.borderWidth = DesignTokens.glassBorderWidth
        let borderAlpha = DesignTokens.glassBorderAlphaLow
            + (DesignTokens.glassBorderAlphaHigh - DesignTokens.glassBorderAlphaLow) * liquid
        panelBackgroundView.layer?.borderColor = NSColor.white
            .withAlphaComponent(borderAlpha).cgColor
        guard let effectView = panelBackgroundView as? NSVisualEffectView else { return }
        effectView.wantsLayer = true
        effectView.layer?.backgroundColor = NSColor.clear.cgColor
    }

    /// Pre-macOS-26 fallback. Foreground content is still embedded inside the
    /// material view, matching the native hierarchy as closely as possible.
    private static func makeFallbackBackgroundView() -> NSView {
        let effectView = NSVisualEffectView()
        effectView.material = DesignTokens.panelMaterial
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = DesignTokens.panelCornerRadius
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        return effectView
    }

    private func layoutGlassHierarchy(panelSize: NSSize) {
        let frame = NSRect(origin: .zero, size: panelSize)
        glassRootView.frame = frame

        if let group = glassGroupView {
            group.frame = glassRootView.bounds
            panelBackgroundView.frame = group.bounds
        } else {
            panelBackgroundView.frame = frame
        }
        chromeView.frame = panelBackgroundView.bounds
    }

    private func setSettingsControlFrame(_ frame: NSRect) {
        if let settingsGlassView {
            settingsGlassView.frame = frame
            settingsButton.frame = settingsGlassView.bounds
        } else {
            settingsButton.frame = frame
        }
    }

    private enum RootPointerAction: Equatable {
        case close(Int)
        case item(Int)
        case pin
        case settings
        case permission
    }

    /// Resolve clicks at the NSPanel boundary. Liquid Glass is visual material,
    /// not part of the interaction contract.
    public override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            let hostPoint = hostView.convert(event.locationInWindow, from: nil)
            if let action = rootPointerAction(atHostPoint: hostPoint) {
                switch action {
                case .close(let index):
                    onItemCloseRequested?(index)
                case .item(let index):
                    onItemClicked?(index)
                case .pin:
                    onPinRequested?()
                case .settings:
                    onSettingsRequested?()
                case .permission:
                    onPreviewPermissionRequested?()
                }
                return
            }
        }
        super.sendEvent(event)
    }

    private func rootPointerAction(atHostPoint point: NSPoint) -> RootPointerAction? {
        if pinButton.isEnabled,
           pinButton.alphaValue > 0.01,
           pinHitFrameInHost.contains(point) {
            return .pin
        }
        if settingsButton.isEnabled,
           (settingsGlassView ?? settingsButton).alphaValue > 0.01,
           settingsHitFrameInHost.contains(point) {
            return .settings
        }

        if !permissionButton.isHidden,
           permissionHitFrameInHost.contains(point) {
            return .permission
        }

        if visibleTileCount > 0 {
            for index in stride(from: visibleTileCount - 1, through: 0, by: -1) {
                let tile = tilePool[index]
                guard !tile.isHidden,
                      let hitFrame = tile.closeControlFrame(in: hostView),
                      hitFrame.contains(point) else { continue }
                return .close(index)
            }
            for index in stride(from: visibleTileCount - 1, through: 0, by: -1) {
                let tile = tilePool[index]
                guard !tile.isHidden else { continue }
                let hitFrame = tile.convert(tile.bounds, to: hostView)
                if hitFrame.contains(point) { return .item(index) }
            }
        }
        return nil
    }

    private var pinHitFrameInHost: NSRect {
        guard let parent = pinButton.superview else { return .zero }
        return parent.convert(pinButton.frame, to: hostView)
    }

    private var settingsHitFrameInHost: NSRect {
        let surface = settingsGlassView ?? settingsButton
        guard let parent = surface.superview else { return .zero }
        return parent.convert(surface.frame, to: hostView)
    }

    private var permissionHitFrameInHost: NSRect {
        guard let parent = permissionButton.superview else { return .zero }
        return parent.convert(permissionButton.frame, to: hostView)
    }

    public func show(items: [SwitcherItem],
                     selectedIndex: Int,
                     presentationMode: SwitcherPresentationMode) {
        self.presentationMode = presentationMode
        hostView.setPointerInside(false)
        update(items: items, selectedIndex: selectedIndex)
        orderFrontRegardless()
        hostView.refreshPointerLocation()
        updateSettingsButtonVisibility(animated: false)
        announceSelection()
        DebugLog.log("panel shown: \(items.count) tiles (\(mode.rawValue)), frame \(frame)")
    }

    /// Re-presents the panel after another modal UI temporarily hid it.
    public func presentAgain(presentationMode: SwitcherPresentationMode) {
        self.presentationMode = presentationMode
        orderFrontRegardless()
        hostView.refreshPointerLocation()
        updateSettingsButtonVisibility(animated: false)
    }

    private struct ReflowGeometry {
        let windowFrame: NSRect
        let glassRootFrame: NSRect
        let glassGroupFrame: NSRect?
        let backgroundFrame: NSRect
        let chromeFrame: NSRect
        let densityFrame: NSRect
        let scrollFrame: NSRect
        let clipBounds: NSRect
        let documentFrame: NSRect
        let settingsFrame: NSRect
        let permissionFrame: NSRect
        let lensFrame: NSRect
        let tileFrames: [AnyHashable: NSRect]
    }

    public func update(items: [SwitcherItem],
                       selectedIndex index: Int,
                       animatedLayout: Bool = false) {
        reflowGeneration &+= 1
        let updateReflowGeneration = reflowGeneration

        if expandedPreviewID != nil {
            expandedPreviewID = nil
            expandedPreviewView.isHidden = true
            scrollView.isHidden = false
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let shouldAnimateReflow = animatedLayout && isVisible && !reduceMotion
        let oldGeometry = shouldAnimateReflow
            ? captureReflowGeometry(usePresentationFrames: true)
            : nil

        mode = Preferences.shared.appearanceMode
        self.items = items
        let liveIDs = Set(items.map(\.id))
        dismissalGhostIDs.formIntersection(liveIDs)
        selectedIndex = index
        itemIndexByID.removeAll(keepingCapacity: true)
        itemIndexByID.reserveCapacity(items.count)
        for (itemIndex, item) in items.enumerated() where itemIndexByID[item.id] == nil {
            itemIndexByID[item.id] = itemIndex
        }

        rebuildTiles(items: items)
        let targetWindowFrame = layoutOnPlacementScreen(
            tileCount: items.count,
            deferWindowFrame: shouldAnimateReflow)
        applySelection(fullRefresh: true)

        if shouldAnimateReflow,
           let oldGeometry,
           let targetWindowFrame {
            let targetGeometry = captureReflowGeometry(
                usePresentationFrames: false,
                windowFrameOverride: targetWindowFrame)
            restoreReflowGeometry(oldGeometry)
            animateUnifiedReflow(to: targetGeometry,
                                 generation: updateReflowGeneration)
        }
    }

    public func select(_ index: Int) {
        selectedIndex = index
        applySelection()
        announceSelection()
    }

    /// A capture arrived for a window in the open session: fill in tiles that
    /// had no snapshot, or crossfade a cached snapshot to the fresh one.
    /// Delivery is keyed by the window's stable id — never by tile position —
    /// so a preview can never land on another window's card.
    public func updatePreview(id: AnyHashable, image: NSImage) {
        guard let index = itemIndexByID[id], index < visibleTileCount else { return }
        tilePool[index].setPreview(image, fadeIn: true)
    }

    /// A capture could not be produced for this window and no cached image is
    /// available. The tile keeps its fixed geometry and shows a semantic
    /// fallback instead of looking empty or broken.
    public func updatePreviewUnavailable(id: AnyHashable) {
        guard let index = itemIndexByID[id], index < visibleTileCount else { return }
        tilePool[index].setPreviewUnavailable()
    }

    /// Applies one permission state to every preview canvas and exposes a
    /// single global action instead of repeating a button on each card.
    public func setPreviewPermissionStatus(_ status: ScreenRecordingPermission.Status) {
        guard mode == .windowPreviews else {
            permissionButton.isHidden = true
            return
        }
        permissionButton.isHidden = status.isAuthorized
        for tile in tilePool.prefix(visibleTileCount) {
            if status.isAuthorized {
                tile.setPreviewLoading()
            } else {
                tile.setPreviewPermissionUnavailable()
            }
        }
    }

    private func item(forID id: AnyHashable) -> SwitcherItem? {
        guard let index = itemIndexByID[id], index >= 0, index < items.count else { return nil }
        return items[index]
    }

    /// Shows the latest available snapshot at a larger size inside my-alt-tab.
    /// This method performs no application/window action.
    public func showExpandedPreview(id: AnyHashable, image: NSImage) {
        guard mode == .windowPreviews,
              let item = item(forID: id) else { return }
        expandedPreviewID = id
        expandedPreviewView.configure(item: item, image: image)
        expandedPreviewView.isHidden = false
        scrollView.isHidden = true
        layoutExpandedPreview()
    }

    public func updateExpandedPreview(id: AnyHashable, image: NSImage) {
        guard expandedPreviewID == id,
              let item = item(forID: id) else { return }
        expandedPreviewView.configure(item: item, image: image)
    }

    public func hideExpandedPreview() {
        guard expandedPreviewID != nil else { return }
        expandedPreviewID = nil
        expandedPreviewView.isHidden = true
        expandedPreviewView.clear()
        scrollView.isHidden = false
        layoutOnPlacementScreen(tileCount: visibleTileCount)
    }

    public func hide() {
        reflowGeneration &+= 1
        hostView.setPointerInside(false)
        selectionLensView.layer?.removeAnimation(forKey: "selectionLensMove")
        selectionLensView.isHidden = true
        expandedPreviewView.clear()
        dismissalGhostIDs.removeAll(keepingCapacity: true)
        for tile in tilePool.prefix(visibleTileCount) {
            tile.setDismissalGhostHidden(false)
            tile.releaseTransientPreview()
        }
        orderOut(nil)
    }

    /// Plays one fixed-cost close flourish above the tile. Dust is biased
    /// inward and upward, keeping more of the plume visible while the centered
    /// panel performs its simultaneous shrink.
    public func playDismissalEffect(at index: Int) {
        guard index >= 0, index < visibleTileCount,
              index < items.count else { return }
        let tile = tilePool[index]
        guard let snapshot = tile.snapshotForDismissalEffect() else { return }

        let overlayFrame = tile.convert(tile.bounds, to: chromeView)
        let horizontal: CGFloat = overlayFrame.midX < chromeView.bounds.midX ? 0.72 : -0.72
        let effect = WindowDismissalEffectView(
            frame: overlayFrame,
            snapshot: snapshot,
            driftDirection: CGVector(dx: horizontal, dy: 1))

        // Hide the real pooled tile only after its snapshot exists. Any hole in
        // the animated mask now exposes the glass behind it, not a duplicate
        // copy of the thumbnail.
        dismissalGhostIDs.insert(items[index].id)
        tile.setDismissalGhostHidden(true)

        chromeView.addSubview(effect, positioned: .above, relativeTo: scrollView)
        effect.play()
    }

    // MARK: - Layout

    private func rebuildTiles(items: [SwitcherItem]) {
        while tilePool.count < items.count {
            let tile = SwitcherTileView()
            tile.isHidden = true
            tilesContainer.addSubview(tile)
            tilePool.append(tile)
        }

        // Preserve physical NSView/layer identity by stable window ID.
        //
        // The old index-based pool shifted B into A's view, C into B's view,
        // etc. whenever an early item disappeared. That forced every trailing
        // card to rebind text/icon/preview state immediately before FLIP, which
        // could stall the main thread and visually turn the first reflow frames
        // into a jump. Surviving windows now keep their original view/layer;
        // reflow only changes their geometry.
        let nextIDs = Set(items.map(\.id))
        var stableViews: [AnyHashable: SwitcherTileView] = [:]
        stableViews.reserveCapacity(min(visibleTileCount, items.count))
        var reusableViews: [SwitcherTileView] = []
        reusableViews.reserveCapacity(tilePool.count)

        for (index, tile) in tilePool.enumerated() {
            if index < visibleTileCount,
               let id = tile.representedIDForReuse,
               nextIDs.contains(id),
               stableViews[id] == nil {
                stableViews[id] = tile
            } else {
                reusableViews.append(tile)
            }
        }

        var orderedVisible: [SwitcherTileView] = []
        orderedVisible.reserveCapacity(items.count)
        for item in items {
            if let stable = stableViews.removeValue(forKey: item.id) {
                orderedVisible.append(stable)
            } else if let reusable = reusableViews.popLast() {
                orderedVisible.append(reusable)
            } else {
                // Defensive only: the pool is grown above, so this path should
                // never execute unless duplicate/invalid identities exhaust it.
                let tile = SwitcherTileView()
                tilesContainer.addSubview(tile)
                orderedVisible.append(tile)
            }
        }

        // Any unmatched stable view is no longer visible. Append every spare
        // after the live prefix so the rest of the panel can continue treating
        // tilePool[index] as the current logical item at index.
        reusableViews.append(contentsOf: stableViews.values)
        tilePool = orderedVisible + reusableViews

        for (index, tile) in tilePool.enumerated() {
            if index < items.count {
                let item = items[index]
                tile.configure(item: item,
                               mode: mode,
                               showTabCounts: Preferences.shared.showTabCounts,
                               preview: PreviewProvider.shared.cachedPreview(for: item.id),
                               displayAspect: placementDisplayAspect)
                tile.onClick = { [weak self] in self?.onItemClicked?(index) }
                tile.onCloseRequest = { [weak self] in self?.onItemCloseRequested?(index) }
                tile.resetHoverState()
                tile.setDismissalGhostHidden(dismissalGhostIDs.contains(item.id))
                tile.isHidden = false
            } else {
                tile.resetHoverState()
                tile.setDismissalGhostHidden(false)
                tile.releaseTransientPreview()
                tile.isHidden = true
            }
        }
        visibleTileCount = items.count
    }

    @discardableResult
    private func layoutOnPlacementScreen(tileCount: Int,
                                         deferWindowFrame: Bool = false) -> NSRect? {
        guard let screen = layoutScreen else { return nil }
        let padding = DesignTokens.panelPadding
        let spacing = DesignTokens.tileSpacing
        let rowSpacing = DesignTokens.tileRowSpacing
        let selectionOverflow = DesignTokens.selectionVisualOverflow
        let tileSize = SwitcherTileView.Metrics.metrics(
            for: mode,
            showTabCounts: Preferences.shared.showTabCounts,
            displayAspect: placementDisplayAspect).tileSize
        let visibleFrame = screen.visibleFrame

        // tiles wrap into rows instead of scrolling horizontally (the AltTab
        // layout model); tiles never shrink. Only an extreme window count
        // exceeds the height budget and falls back to vertical scrolling.
        let horizontalCapacityPadding = padding
            + (DesignTokens.panelTrailingComfort + selectionOverflow) / 2
        let capacity = SwitcherGridCapacity.columns(
            visibleWidth: visibleFrame.width,
            tileWidth: tileSize.width,
            spacing: spacing,
            padding: horizontalCapacityPadding,
            maxWidthFraction: DesignTokens.panelMaxWidthFraction,
            tileCount: tileCount)
        // a mirrored group imposes the most constrained display's grid on every
        // panel, so the same layout is guaranteed to fit on all of them
        let columns = max(1, min(capacity, sharedColumnLimit ?? capacity))
        let rows = tileCount == 0 ? 1 : Int(ceil(Double(tileCount) / Double(columns)))
        columnsPerRow = columns

        let visibleColumns = min(tileCount, columns)
        let contentGridWidth = CGFloat(visibleColumns) * tileSize.width
            + CGFloat(max(0, visibleColumns - 1)) * spacing
        let contentGridHeight = CGFloat(rows) * tileSize.height
            + CGFloat(max(0, rows - 1)) * rowSpacing
        // NSClipView clips strictly to the document view. The selected tile
        // intentionally draws outside its nominal tile frame (glass lens +
        // glow + compositor scale), so reserve a real document gutter instead
        // of relying on panel padding that exists outside the clip view.
        let leadingOverflow = max(
            DesignTokens.closeButtonLeadingOverflow, selectionOverflow)
        let trailingOverflow = selectionOverflow
        let topOverflow = max(
            DesignTokens.closeButtonTopOverflow, selectionOverflow)
        let bottomOverflow = selectionOverflow
        let documentWidth = contentGridWidth + leadingOverflow + trailingOverflow
        let documentHeight = contentGridHeight + topOverflow + bottomOverflow
        tilesContainer.frame = NSRect(x: 0, y: 0,
                                      width: documentWidth, height: documentHeight)
        selectionFrames.removeAll(keepingCapacity: true)
        selectionFrames.reserveCapacity(tileCount)
        for (index, tile) in tilePool.prefix(tileCount).enumerated() {
            let column = index % columns
            let row = index / columns
            // Full rows naturally occupy the whole grid. Window Previews lets
            // the user align only an incomplete row; App Icons preserve the
            // original centered native-switcher behavior.
            let tilesInRow = min(columns, tileCount - row * columns)
            let rowWidth = CGFloat(tilesInRow) * tileSize.width
                + CGFloat(max(0, tilesInRow - 1)) * spacing
            let rowAlignment = mode == .windowPreviews
                ? Preferences.shared.previewRowAlignment
                : .center
            let rowOffset = rowAlignment.leadingOffset(
                remainingWidth: contentGridWidth - rowWidth)
            let tileFrame = NSRect(
                x: leadingOverflow + rowOffset + CGFloat(column) * (tileSize.width + spacing),
                y: bottomOverflow
                    + CGFloat(rows - 1 - row) * (tileSize.height + rowSpacing),
                width: tileSize.width,
                height: tileSize.height)
            tile.frame = tileFrame
            selectionFrames.append(tileFrame.insetBy(
                dx: -DesignTokens.selectionLensInset,
                dy: -DesignTokens.selectionLensInset))
        }

        let verticalCapacityPadding = padding
            + (DesignTokens.chromeReservedTop
                + DesignTokens.panelBottomComfort
                + selectionOverflow) / 2
        let rowCapacity = SwitcherGridCapacity.maxVisibleRows(
            visibleHeight: visibleFrame.height,
            tileHeight: tileSize.height,
            rowSpacing: rowSpacing,
            padding: verticalCapacityPadding,
            maxHeightFraction: DesignTokens.panelMaxHeightFraction)
        let maxVisibleRows = max(1, min(rowCapacity, sharedRowLimit ?? rowCapacity))
        let visibleRows = min(rows, maxVisibleRows)
        let visibleGridHeight = CGFloat(visibleRows) * tileSize.height
            + CGFloat(max(0, visibleRows - 1)) * rowSpacing
        scrollView.frame = NSRect(
            x: padding - leadingOverflow,
            y: padding + DesignTokens.panelBottomComfort,
            width: documentWidth,
            height: visibleGridHeight + topOverflow + bottomOverflow)
        // start reading from the first row (top of the grid)
        tilesContainer.scroll(NSPoint(
            x: 0,
            y: max(0, contentGridHeight - visibleGridHeight)))

        let panelSize = NSSize(
            width: contentGridWidth + padding * 2
                + DesignTokens.panelTrailingComfort + trailingOverflow,
            height: visibleGridHeight + padding * 2
                + DesignTokens.panelBottomComfort
                + DesignTokens.chromeReservedTop + bottomOverflow)
        layoutGlassHierarchy(panelSize: panelSize)

        // The empty top chrome stays clear. Frosted density only belongs to the
        // content zone and fades out before it reaches the reserved ellipsis row.
        let densityHeight = min(
            panelSize.height,
            scrollView.frame.maxY + DesignTokens.panelPadding)
        liquidGlassDensityView.frame = NSRect(
            x: 0,
            y: 0,
            width: panelSize.width,
            height: densityHeight)
        liquidGlassDensityMask.frame = liquidGlassDensityView.bounds

        // v2.3 gives global controls their own top chrome strip. The ellipsis
        // is still visually attached to the panel, but it never intersects a
        // thumbnail or selection lens.
        let controlSize = DesignTokens.chromeButtonHitSize
        let controlInset = DesignTokens.settingsButtonInset
        setSettingsControlFrame(NSRect(
            x: panelSize.width - controlSize - controlInset,
            y: panelSize.height - controlSize - controlInset,
            width: controlSize, height: controlSize))
        permissionButton.frame = NSRect(
            x: panelSize.width - controlSize * 2 - controlInset - 6,
            y: panelSize.height - controlSize - controlInset,
            width: controlSize, height: controlSize)
        let origin = NSPoint(x: visibleFrame.midX - panelSize.width / 2,
                             y: visibleFrame.midY - panelSize.height / 2)
        let targetFrame = NSRect(origin: origin, size: panelSize)
        if !deferWindowFrame {
            setFrame(targetFrame, display: true)
        }
        return targetFrame
    }

    /// Stable-ID FLIP capture. Presentation frames are used at interruption
    /// points, so a second close begins from the pixels currently visible
    /// instead of snapping back to an earlier model frame.
    private func captureReflowGeometry(
        usePresentationFrames: Bool,
        windowFrameOverride: NSRect? = nil) -> ReflowGeometry {
        var tileFrames: [AnyHashable: NSRect] = [:]
        tileFrames.reserveCapacity(min(items.count, visibleTileCount))
        for (index, item) in items.enumerated() where index < visibleTileCount {
            guard tileFrames[item.id] == nil else { continue }
            tileFrames[item.id] = usePresentationFrames
                ? presentationFrame(of: tilePool[index])
                : tilePool[index].frame
        }

        return ReflowGeometry(
            windowFrame: windowFrameOverride ?? frame,
            glassRootFrame: usePresentationFrames
                ? presentationFrame(of: glassRootView)
                : glassRootView.frame,
            glassGroupFrame: glassGroupView.map {
                usePresentationFrames ? presentationFrame(of: $0) : $0.frame
            },
            backgroundFrame: usePresentationFrames
                ? presentationFrame(of: panelBackgroundView)
                : panelBackgroundView.frame,
            chromeFrame: usePresentationFrames
                ? presentationFrame(of: chromeView)
                : chromeView.frame,
            densityFrame: usePresentationFrames
                ? presentationFrame(of: liquidGlassDensityView)
                : liquidGlassDensityView.frame,
            scrollFrame: usePresentationFrames
                ? presentationFrame(of: scrollView)
                : scrollView.frame,
            clipBounds: scrollView.contentView.bounds,
            documentFrame: usePresentationFrames
                ? presentationFrame(of: tilesContainer)
                : tilesContainer.frame,
            settingsFrame: {
                let settingsSurface = settingsGlassView ?? settingsButton
                return usePresentationFrames
                    ? presentationFrame(of: settingsSurface)
                    : settingsSurface.frame
            }(),
            permissionFrame: usePresentationFrames
                ? presentationFrame(of: permissionButton)
                : permissionButton.frame,
            lensFrame: usePresentationFrames
                ? presentationFrame(of: selectionLensView)
                : selectionLensView.frame,
            tileFrames: tileFrames)
    }

    private func presentationFrame(of view: NSView) -> NSRect {
        guard let presentation = view.layer?.presentation() else { return view.frame }
        let bounds = presentation.bounds
        let position = presentation.position
        let anchor = presentation.anchorPoint
        return NSRect(
            x: position.x - bounds.width * anchor.x,
            y: position.y - bounds.height * anchor.y,
            width: bounds.width,
            height: bounds.height)
    }

    private func restoreReflowGeometry(_ old: ReflowGeometry) {
        setFrame(old.windowFrame, display: false)
        glassRootView.frame = old.glassRootFrame
        if let group = glassGroupView, let frame = old.glassGroupFrame {
            group.frame = frame
        }
        panelBackgroundView.frame = old.backgroundFrame
        chromeView.frame = old.chromeFrame
        liquidGlassDensityView.frame = old.densityFrame
        liquidGlassDensityMask.frame = liquidGlassDensityView.bounds
        scrollView.frame = old.scrollFrame
        scrollView.contentView.bounds = old.clipBounds
        tilesContainer.frame = old.documentFrame
        setSettingsControlFrame(old.settingsFrame)
        permissionButton.frame = old.permissionFrame
        selectionLensView.frame = old.lensFrame

        for (index, item) in items.enumerated() where index < visibleTileCount {
            if let oldFrame = old.tileFrames[item.id] {
                tilePool[index].frame = oldFrame
            }
        }
    }

    /// Reflow runs entirely inside one stationary NSWindow compositor space.
    ///
    /// NSWindow frame animation is owned by WindowServer while layer-backed
    /// NSViews animate through Core Animation. Driving both at once with the
    /// same duration/timing function does NOT put them on one render clock:
    /// child positions are relative to a parent window that is itself moving,
    /// so one pipeline arriving a frame earlier looks like a tile teleport.
    ///
    /// Keep the real window at the old frame during motion. Direct host children
    /// (Glass/chrome/global controls) animate toward the target window's
    /// screen-space offset inside that stationary host, while nested content
    /// (scroll/document/tiles/focus lens) uses its normal target-local frames.
    /// At completion the real NSWindow is atomically committed to the target
    /// frame and the host children are normalized back to local coordinates.
    /// The pixels therefore do not move at that hand-off.
    private func animateUnifiedReflow(to target: ReflowGeometry,
                                      generation: UInt64) {
        let animationWindowFrame = frame
        let hostDelta = NSPoint(
            x: target.windowFrame.minX - animationWindowFrame.minX,
            y: target.windowFrame.minY - animationWindowFrame.minY)

        @inline(__always)
        func visualTargetFrame(_ targetFrame: NSRect, for view: NSView) -> NSRect {
            guard view.superview === hostView else { return targetFrame }
            return targetFrame.offsetBy(dx: hostDelta.x, dy: hostDelta.y)
        }

        let settingsSurface = settingsGlassView ?? settingsButton

        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.panelReflowDuration
            context.timingFunction = DesignTokens.panelReflowTimingFunction
            context.allowsImplicitAnimation = true

            // Deliberately DO NOT animate the NSWindow. Everything the user can
            // see moves on the same layer-backed AppKit/Core Animation clock.
            glassRootView.animator().frame =
                visualTargetFrame(target.glassRootFrame, for: glassRootView)
            if let group = glassGroupView, let groupFrame = target.glassGroupFrame {
                group.animator().frame =
                    visualTargetFrame(groupFrame, for: group)
            }
            // glassRootView and panelBackgroundView are normally the same view.
            // Avoid scheduling the same animatable property twice.
            if panelBackgroundView !== glassRootView {
                panelBackgroundView.animator().frame =
                    visualTargetFrame(target.backgroundFrame, for: panelBackgroundView)
            }
            chromeView.animator().frame =
                visualTargetFrame(target.chromeFrame, for: chromeView)
            liquidGlassDensityView.animator().frame = target.densityFrame
            scrollView.animator().frame = target.scrollFrame

            // Scrolling geometry is part of the same motion. 3.4.5 restored the
            // old clip bounds before FLIP but never animated/committed the target
            // bounds, which could make multi-row lists visibly jump.
            scrollView.contentView.animator().bounds = target.clipBounds
            tilesContainer.animator().frame = target.documentFrame

            settingsSurface.animator().frame =
                visualTargetFrame(target.settingsFrame, for: settingsSurface)
            permissionButton.animator().frame =
                visualTargetFrame(target.permissionFrame, for: permissionButton)

            for (index, item) in items.enumerated() where index < visibleTileCount {
                if let targetFrame = target.tileFrames[item.id] {
                    tilePool[index].animator().frame = targetFrame
                }
            }
            if !selectionLensView.isHidden {
                selectionLensView.animator().frame = target.lensFrame
            }
        } completionHandler: { [weak self] in
            guard let self,
                  self.reflowGeneration == generation else { return }

            // display:false lets AppKit coalesce the window hand-off with the
            // local-frame normalization below. Before the hand-off the visible
            // top-level frame is targetLocal + hostDelta; afterwards the window
            // origin contributes that same delta and the local frame is targetLocal.
            // Screen-space pixels therefore remain continuous.
            self.setFrame(target.windowFrame, display: false)

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.glassRootView.frame = target.glassRootFrame
            if let group = self.glassGroupView, let groupFrame = target.glassGroupFrame {
                group.frame = groupFrame
            }
            if self.panelBackgroundView !== self.glassRootView {
                self.panelBackgroundView.frame = target.backgroundFrame
            }
            self.chromeView.frame = target.chromeFrame
            self.liquidGlassDensityView.frame = target.densityFrame
            self.liquidGlassDensityMask.frame = self.liquidGlassDensityView.bounds
            self.scrollView.frame = target.scrollFrame
            self.scrollView.contentView.bounds = target.clipBounds
            self.tilesContainer.frame = target.documentFrame
            self.setSettingsControlFrame(target.settingsFrame)
            self.permissionButton.frame = target.permissionFrame
            if !self.selectionLensView.isHidden {
                self.selectionLensView.frame = target.lensFrame
            }
            for (index, item) in self.items.enumerated()
            where index < self.visibleTileCount {
                if let targetFrame = target.tileFrames[item.id] {
                    self.tilePool[index].frame = targetFrame
                }
            }
            CATransaction.commit()

            self.displayIfNeeded()
        }
    }

    private func layoutExpandedPreview() {
        guard let screen = layoutScreen else { return }
        let visibleFrame = screen.visibleFrame
        let currentSize = panelBackgroundView.frame.size
        let panelSize = NSSize(
            width: min(max(currentSize.width, DesignTokens.expandedPreviewMinimumWidth),
                       visibleFrame.width * DesignTokens.panelMaxWidthFraction),
            height: min(max(currentSize.height, DesignTokens.expandedPreviewMinimumHeight),
                        visibleFrame.height * DesignTokens.panelMaxHeightFraction))
        layoutGlassHierarchy(panelSize: panelSize)
        liquidGlassDensityView.frame = chromeView.bounds
        liquidGlassDensityMask.frame = liquidGlassDensityView.bounds
        expandedPreviewView.frame = panelBackgroundView.bounds.insetBy(
            dx: DesignTokens.expandedPreviewPanelInset,
            dy: DesignTokens.expandedPreviewPanelInset)
        let controlSize = DesignTokens.chromeButtonHitSize
        let controlInset = DesignTokens.settingsButtonInset
        setSettingsControlFrame(NSRect(
            x: panelSize.width - controlSize - controlInset,
            y: panelSize.height - controlSize - controlInset,
            width: controlSize, height: controlSize))
        permissionButton.isHidden = true
        let origin = NSPoint(x: visibleFrame.midX - panelSize.width / 2,
                             y: visibleFrame.midY - panelSize.height / 2)
        setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }

    private func applySelection(fullRefresh: Bool = false) {
        let previousIndex = appliedSelectedIndex
        if fullRefresh {
            for (index, tile) in tilePool.prefix(visibleTileCount).enumerated() {
                tile.isSelected = index == selectedIndex
            }
        } else {
            if previousIndex != selectedIndex,
               previousIndex >= 0, previousIndex < visibleTileCount {
                tilePool[previousIndex].isSelected = false
            }
            if selectedIndex >= 0, selectedIndex < visibleTileCount {
                tilePool[selectedIndex].isSelected = true
            }
        }
        moveSelectionLens(from: previousIndex, to: selectedIndex, animated: !fullRefresh)
        appliedSelectedIndex = selectedIndex
        if selectedIndex >= 0, selectedIndex < visibleTileCount {
            tilePool[selectedIndex].scrollToVisible(tilePool[selectedIndex].bounds)
        }
    }

    private func moveSelectionLens(from previousIndex: Int, to index: Int, animated: Bool) {
        guard index >= 0, index < selectionFrames.count else {
            selectionLensView.layer?.removeAnimation(forKey: "selectionLensMove")
            selectionLensView.isHidden = true
            return
        }
        let targetFrame = selectionFrames[index]
        guard !selectionLensView.isHidden else {
            selectionLensView.frame = targetFrame
            selectionLensView.isHidden = false
            return
        }

        let duration = SelectionMotion.duration(from: previousIndex, to: index, columns: columnsPerRow)
        let shouldAnimate = animated && isVisible && duration > 0
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldAnimate, let layer = selectionLensView.layer else {
            selectionLensView.layer?.removeAnimation(forKey: "selectionLensMove")
            selectionLensView.frame = targetFrame
            return
        }

        let presentation = layer.presentation()
        let fromPosition = presentation?.position ?? layer.position
        let fromBounds = presentation?.bounds ?? layer.bounds

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionLensView.frame = targetFrame
        CATransaction.commit()

        let position = CABasicAnimation(keyPath: "position")
        position.fromValue = NSValue(point: fromPosition)
        position.toValue = NSValue(point: layer.position)
        let bounds = CABasicAnimation(keyPath: "bounds")
        bounds.fromValue = NSValue(rect: fromBounds)
        bounds.toValue = NSValue(rect: layer.bounds)

        let group = CAAnimationGroup()
        group.animations = [position, bounds]
        group.duration = duration
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.18, 0.82, 0.20, 1.0)
        layer.add(group, forKey: "selectionLensMove")
    }

    private func announceSelection() {
        guard selectedIndex >= 0, selectedIndex < visibleTileCount else { return }
        NSAccessibility.post(element: NSApp as Any,
                             notification: .announcementRequested,
                             userInfo: [.announcement: tilePool[selectedIndex].accessibilityText,
                                        .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    /// Test hook: whether the tile at `index` currently shows a snapshot image
    /// (regression coverage for preview/window association).
    func tileShowsPreviewForTesting(at index: Int) -> Bool {
        index >= 0 && index < visibleTileCount && tilePool[index].showsPreviewImage
    }

    func tileFrameForTesting(at index: Int) -> NSRect? {
        index >= 0 && index < visibleTileCount ? tilePool[index].frame : nil
    }

    func tileForTesting(at index: Int) -> SwitcherTileView? {
        index >= 0 && index < visibleTileCount ? tilePool[index] : nil
    }

    func closeFrameForTesting(at index: Int) -> NSRect? {
        guard let tile = tileForTesting(at: index) else { return nil }
        return tile.convert(tile.closeFrameForTesting, to: hostView)
    }

    /// Explicit offscreen-render hook used by the documentation harness.
    /// Production close visibility remains hover-driven.
    var selectedIndexForTesting: Int { selectedIndex }

    public func prepareCloseForRendering(at index: Int?) {
        for tile in tilePool.prefix(visibleTileCount) {
            tile.prepareCloseControlForRendering(visible: false)
        }
        if let index {
            tileForTesting(at: index)?.prepareCloseControlForRendering(visible: true)
        }
    }

    var selectionLensFrameForTesting: NSRect { selectionLensView.frame }
    var selectionLensIsVisibleForTesting: Bool { !selectionLensView.isHidden }
    var selectionLensUsesGlassMaterialForTesting: Bool {
        selectionLensView.usesLiquidGlassMaterialForTesting
    }
    var liquidGlassDensityAlphaForTesting: CGFloat {
        liquidGlassDensityView.layer?.backgroundColor?.alpha ?? 0
    }
    var liquidGlassSurfaceAlphaForTesting: CGFloat {
        panelBackgroundView.alphaValue
    }
    var foregroundChromeUsesGlassContentViewForTesting: Bool {
        chromeView.superview === panelBackgroundView
    }
    var foregroundChromeIsSiblingAboveGlassForTesting: Bool {
        chromeView.superview === hostView && panelBackgroundView.superview === hostView
    }
    var usesNativeGlassBackgroundForTesting: Bool { usesNativeGlassBackground }
    var nativeGlassRuntimeSupportsInteractionForTesting: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *),
           let glass = panelBackgroundView as? NSGlassEffectView {
            return glass.responds(to: NSSelectorFromString("setEffectIsInteractive:"))
        }
        #endif
        return false
    }
    var nativeGlassHasManualBorderForTesting: Bool {
        panelBackgroundView.layer?.borderWidth ?? 0 > 0
    }
    func closeTargetIndexForTesting(atHostPoint point: NSPoint) -> Int? {
        guard case .close(let index) = rootPointerAction(atHostPoint: point) else {
            return nil
        }
        return index
    }
    func itemTargetIndexForTesting(atHostPoint point: NSPoint) -> Int? {
        guard case .item(let index) = rootPointerAction(atHostPoint: point) else {
            return nil
        }
        return index
    }
    func settingsTargetForTesting(atHostPoint point: NSPoint) -> Bool {
        rootPointerAction(atHostPoint: point) == .settings
    }
    var settingsHitFrameInHostForTesting: NSRect { settingsHitFrameInHost }
    var usesUnifiedReflowForTesting: Bool { true }
    var selectionLensDensityAlphaForTesting: CGFloat {
        selectionLensView.densityAlphaForTesting
    }
    var selectionLensBorderWidthForTesting: CGFloat {
        selectionLensView.borderWidthForTesting
    }
    var selectionLensBorderColorForTesting: NSColor? {
        selectionLensView.borderColorForTesting
    }
    var liquidGlassDensityFrameForTesting: NSRect {
        liquidGlassDensityView.frame
    }
    var selectionGeometryCountForTesting: Int { selectionFrames.count }

    var settingsButtonFrameForTesting: NSRect {
        (settingsGlassView ?? settingsButton).frame
    }
    var settingsButtonIsVisibleForTesting: Bool {
        let surface = settingsGlassView ?? settingsButton
        return settingsButton.isEnabled && surface.alphaValue > 0
    }
    var settingsButtonToolTipForTesting: String? { settingsButton.toolTip }
    var gridFrameForTesting: NSRect { scrollView.frame }
    var documentFrameForTesting: NSRect { tilesContainer.frame }
    var selectionLensFrameInDocumentForTesting: NSRect { selectionLensView.frame }
    var selectionLensVisualBoundsForTesting: NSRect {
        selectionLensView.frame.insetBy(
            dx: -DesignTokens.selectionLensGlowRadius,
            dy: -DesignTokens.selectionLensGlowRadius)
    }
    var gridRightInsetForTesting: CGFloat {
        panelBackgroundView.frame.maxX - scrollView.frame.maxX
    }
    var gridBottomInsetForTesting: CGFloat {
        scrollView.frame.minY - panelBackgroundView.frame.minY
    }
    var settingsButtonIntersectsGridForTesting: Bool {
        (settingsGlassView ?? settingsButton).frame.intersects(scrollView.frame)
    }
    var panelBackgroundFrameForTesting: NSRect { panelBackgroundView.frame }

    func setPanelHoverForTesting(_ hovered: Bool) {
        hostView.setPointerInside(hovered)
        updateSettingsButtonVisibility(animated: false)
    }

    private func updateSettingsButtonVisibility(animated: Bool) {
        let visible = presentationMode == .persistent || hostView.isPointerInside
        settingsButton.isEnabled = visible
        settingsButton.setAccessibilityHidden(!visible)
        let target: CGFloat = visible ? 1 : 0
        let visibilitySurface = settingsGlassView ?? settingsButton
        guard visibilitySurface.alphaValue != target else { return }
        let shouldAnimate = animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldAnimate else {
            visibilitySurface.alphaValue = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.settingsVisibilityFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            visibilitySurface.animator().alphaValue = target
        }
    }

    @objc private func settingsClicked() {
        onSettingsRequested?()
    }

    @objc private func permissionClicked() {
        onPreviewPermissionRequested?()
    }
}
