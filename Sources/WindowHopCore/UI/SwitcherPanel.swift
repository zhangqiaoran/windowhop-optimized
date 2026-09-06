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

/// A single shared glass lens follows the selection. Keeping exactly one
/// NSVisualEffectView avoids the N-card blur cost while still making the active
/// preview look translucent and native.
private final class SelectionLensView: NSVisualEffectView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .selection
        blendingMode = .withinWindow
        state = .active
        isEmphasized = true
        wantsLayer = true
        layer?.cornerRadius = DesignTokens.selectionLensCornerRadius
        layer?.cornerCurve = .continuous
        setAccessibilityElement(false)
        refreshAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshAppearance()
    }

    private func refreshAppearance() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = DesignTokens.selectionLensFill.cgColor
            layer?.borderColor = DesignTokens.selectionLensStroke.cgColor
            layer?.borderWidth = DesignTokens.selectionLensBorderWidth
            layer?.shadowColor = DesignTokens.selectionLensGlow.cgColor
            layer?.shadowOpacity = 1
            layer?.shadowRadius = DesignTokens.selectionLensGlowRadius
            layer?.shadowOffset = .zero
        }
    }
}

private final class SwitcherPanelHostView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private(set) var isPointerInside = false

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
public final class SwitcherPanel: NSPanel {
    public var onItemClicked: ((Int) -> Void)?
    /// Hover close control on a tile; routes through the same direct close as Delete.
    public var onItemCloseRequested: ((Int) -> Void)?
    /// The panel-chrome gear control (and ⌘, while a session is open).
    public var onSettingsRequested: (() -> Void)?
    /// One panel-level action when all preview capture is permission-blocked.
    public var onPreviewPermissionRequested: (() -> Void)?

    /// Transparent overflow host. The visible panel occupies only
    /// `panelBackgroundView`; global controls may extend into the host without
    /// changing the panel's internal layout.
    private let hostView = SwitcherPanelHostView()
    private var panelBackgroundView: NSView!
    /// Everything inside the visible panel background (the preview grid).
    private let chromeView = NSView()
    private let scrollView = NSScrollView()
    private let tilesContainer = SwitcherTilesContainerView()
    private let selectionLensView = SelectionLensView()
    /// Cached target frames make every selection transition a direct O(1)
    /// indexed lookup. Geometry is rebuilt only when the window list/layout is.
    private var selectionFrames: [NSRect] = []
    private let settingsButton = NSButton()
    private let permissionButton = NSButton()
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
    /// O(1) delivery lookup for asynchronous preview captures. A session can
    /// deliver many images in quick succession, so repeatedly scanning the list
    /// needlessly scales the UI work with the number of open windows.
    private var itemIndexByID: [AnyHashable: Int] = [:]
    private var expandedPreviewID: AnyHashable?
    private var presentationMode = SwitcherPresentationMode.cycling
    private var accessibilityDisplayObserver: NSObjectProtocol?
    private var panelAppearanceObserver: NSObjectProtocol?
    /// Grid geometry of the current layout, for 2D arrow-key navigation.
    public private(set) var columnsPerRow = 1

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

    /// The preview area a tile offers in Window Previews mode, for capture sizing.
    public static var previewContentSize: NSSize {
        let metrics = SwitcherTileView.Metrics.metrics(
            for: .windowPreviews,
            showTabCounts: Preferences.shared.showTabCounts)
        return NSSize(width: metrics.tileSize.width - DesignTokens.tileLabelInset * 2,
                      height: metrics.contentHeight)
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
        becomesKeyOnlyIfNeeded = true
        isReleasedWhenClosed = false

        // The native switcher's background. On macOS 26+ that is the system
        // glass material (NSGlassEffectView — blur, vibrancy, and edge
        // treatment come from AppKit, never a hardcoded color); older systems
        // fall back to the closest visual-effect material. Both respect
        // Reduce Transparency and Increase Contrast automatically.
        chromeView.autoresizingMask = [.width, .height]
        panelBackgroundView = Self.makeBackgroundView(wrapping: chromeView,
                                                      rasterizable: rasterizableBackground)
        hostView.addSubview(panelBackgroundView)
        contentView = hostView
        applyGlassTransparency()

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
        settingsButton.layer?.backgroundColor = NSColor.controlBackgroundColor
            .withAlphaComponent(0.42).cgColor
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)
        settingsButton.toolTip = "More Options (⌘,)"
        settingsButton.setAccessibilityLabel("More Options")
        settingsButton.alphaValue = 0
        settingsButton.isEnabled = false
        settingsButton.setAccessibilityHidden(true)
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
                self?.applyGlassTransparency()
            }
        panelAppearanceObserver = NotificationCenter.default.addObserver(
            forName: Preferences.panelAppearanceDidChange,
            object: Preferences.shared,
            queue: .main) { [weak self] _ in
                self?.applyGlassTransparency()
            }

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

    /// Applies a neutral system tint on top of the native material instead of
    /// fading the whole background view, so labels, previews, and controls keep
    /// full contrast at every user-selected transparency level.
    private func applyGlassTransparency() {
        let percent = Preferences.clampedGlassTransparency(
            Preferences.shared.glassTransparencyPercent)
        let tintAlpha = CGFloat(1 - percent / 100)
        let tint = NSColor.windowBackgroundColor.withAlphaComponent(tintAlpha)

        #if compiler(>=6.2)
        if #available(macOS 26.0, *),
           let glass = panelBackgroundView as? NSGlassEffectView {
            glass.tintColor = tintAlpha == 0 ? nil : tint
            return
        }
        #endif

        guard let effectView = panelBackgroundView as? NSVisualEffectView else { return }
        effectView.wantsLayer = true
        effectView.layer?.backgroundColor = tint.cgColor
    }

    /// The panel background: system glass on macOS 26+, the closest
    /// visual-effect material before that.
    private static func makeBackgroundView(wrapping content: NSView,
                                           rasterizable: Bool) -> NSView {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !rasterizable {
            let glass = NSGlassEffectView()
            glass.cornerRadius = DesignTokens.panelCornerRadius
            glass.contentView = content
            return glass
        }
        #endif
        let effectView = NSVisualEffectView()
        effectView.material = DesignTokens.panelMaterial
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = DesignTokens.panelCornerRadius
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true
        content.frame = effectView.bounds
        effectView.addSubview(content)
        return effectView
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

    public func update(items: [SwitcherItem], selectedIndex index: Int) {
        if expandedPreviewID != nil {
            expandedPreviewID = nil
            expandedPreviewView.isHidden = true
            scrollView.isHidden = false
        }
        mode = Preferences.shared.appearanceMode
        self.items = items
        selectedIndex = index
        itemIndexByID.removeAll(keepingCapacity: true)
        itemIndexByID.reserveCapacity(items.count)
        for (itemIndex, item) in items.enumerated() where itemIndexByID[item.id] == nil {
            itemIndexByID[item.id] = itemIndex
        }
        rebuildTiles(items: items)
        layoutOnPlacementScreen(tileCount: items.count)
        applySelection(fullRefresh: true)
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
        hostView.setPointerInside(false)
        selectionLensView.layer?.removeAnimation(forKey: "selectionLensMove")
        selectionLensView.isHidden = true
        expandedPreviewView.clear()
        for tile in tilePool.prefix(visibleTileCount) {
            tile.releaseTransientPreview()
        }
        orderOut(nil)
    }

    /// Plays one fixed-cost close flourish above the tile. The effect owns only
    /// a transient snapshot and a fixed 28-particle layer set, then self-removes.
    public func playDismissalEffect(at index: Int) {
        guard index >= 0, index < visibleTileCount else { return }
        let tile = tilePool[index]
        // Convert into chrome coordinates before the session model removes the
        // tile. The overlay then survives grid reflow/shrink independently.
        let overlayFrame = tile.convert(tile.bounds, to: chromeView)
        let effect = WindowDismissalEffectView(
            frame: overlayFrame,
            snapshot: tile.snapshotForDismissalEffect())
        chromeView.addSubview(effect, positioned: .above, relativeTo: scrollView)
        effect.play()
    }

    // MARK: - Layout

    private func rebuildTiles(items: [SwitcherItem]) {
        while tilePool.count < items.count {
            let tile = SwitcherTileView()
            tilesContainer.addSubview(tile)
            tilePool.append(tile)
        }
        for (index, tile) in tilePool.enumerated() {
            if index < items.count {
                let item = items[index]
                tile.configure(item: item,
                               mode: mode,
                               showTabCounts: Preferences.shared.showTabCounts,
                               preview: PreviewProvider.shared.cachedPreview(for: item.id))
                tile.onClick = { [weak self] in self?.onItemClicked?(index) }
                tile.onCloseRequest = { [weak self] in self?.onItemCloseRequested?(index) }
                tile.resetHoverState()
                tile.isHidden = false
            } else {
                tile.resetHoverState()
                tile.releaseTransientPreview()
                tile.isHidden = true
            }
        }
        visibleTileCount = items.count
    }

    private func layoutOnPlacementScreen(tileCount: Int) {
        guard let screen = layoutScreen else { return }
        let padding = DesignTokens.panelPadding
        let spacing = DesignTokens.tileSpacing
        let rowSpacing = DesignTokens.tileRowSpacing
        let selectionOverflow = DesignTokens.selectionVisualOverflow
        let tileSize = SwitcherTileView.Metrics.metrics(
            for: mode,
            showTabCounts: Preferences.shared.showTabCounts).tileSize
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
        panelBackgroundView.frame = NSRect(origin: .zero, size: panelSize)

        // v2.3 gives global controls their own top chrome strip. The ellipsis
        // is still visually attached to the panel, but it never intersects a
        // thumbnail or selection lens.
        let controlSize = DesignTokens.chromeButtonHitSize
        let controlInset = DesignTokens.settingsButtonInset
        settingsButton.frame = NSRect(
            x: panelSize.width - controlSize - controlInset,
            y: panelSize.height - controlSize - controlInset,
            width: controlSize, height: controlSize)
        permissionButton.frame = NSRect(
            x: panelSize.width - controlSize * 2 - controlInset - 6,
            y: panelSize.height - controlSize - controlInset,
            width: controlSize, height: controlSize)
        let origin = NSPoint(x: visibleFrame.midX - panelSize.width / 2,
                             y: visibleFrame.midY - panelSize.height / 2)
        setFrame(NSRect(origin: origin, size: panelSize), display: true)
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
        panelBackgroundView.frame = NSRect(origin: .zero, size: panelSize)
        chromeView.frame = panelBackgroundView.bounds
        expandedPreviewView.frame = panelBackgroundView.bounds.insetBy(
            dx: DesignTokens.expandedPreviewPanelInset,
            dy: DesignTokens.expandedPreviewPanelInset)
        let controlSize = DesignTokens.chromeButtonHitSize
        let controlInset = DesignTokens.settingsButtonInset
        settingsButton.frame = NSRect(
            x: panelSize.width - controlSize - controlInset,
            y: panelSize.height - controlSize - controlInset,
            width: controlSize, height: controlSize)
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
        selectionLensView.material == .selection && selectionLensView.state == .active
    }
    var selectionGeometryCountForTesting: Int { selectionFrames.count }

    var settingsButtonFrameForTesting: NSRect { settingsButton.frame }
    var settingsButtonIsVisibleForTesting: Bool {
        settingsButton.isEnabled && settingsButton.alphaValue > 0
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
        settingsButton.frame.intersects(scrollView.frame)
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
        guard settingsButton.alphaValue != target else { return }
        let shouldAnimate = animated
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        guard shouldAnimate else {
            settingsButton.alphaValue = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignTokens.settingsVisibilityFadeDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            settingsButton.animator().alphaValue = target
        }
    }

    @objc private func settingsClicked() {
        onSettingsRequested?()
    }

    @objc private func permissionClicked() {
        onPreviewPermissionRequested?()
    }
}
