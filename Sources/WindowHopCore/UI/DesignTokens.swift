import AppKit

/// Every size, inset, radius, and font size the switcher UI uses, in one place.
/// Tuned against the native macOS ⌘⇥ switcher's proportions. Views never hardcode
/// dimensions — change a token here and every surface follows.
enum DesignTokens {
    // MARK: Panel chrome
    /// Keeps the complete 44×44 close hit target inside the visible panel without shrinking accessibility.
    static let panelPadding: CGFloat = 26
    /// Extra breathing room is asymmetric on purpose: the grid keeps native
    /// density on the left while the right/bottom edges get a calmer finish.
    static let panelTrailingComfort: CGFloat = 24
    static let panelBottomComfort: CGFloat = 18
    /// A dedicated top chrome strip keeps global actions physically outside the
    /// preview grid instead of floating over the rightmost thumbnail.
    static let chromeReservedTop: CGFloat = 50
    static let panelCornerRadius: CGFloat = 22
    /// The grid may use up to this fraction of the screen's width/height.
    static let panelMaxWidthFraction: CGFloat = 0.90
    static let panelMaxHeightFraction: CGFloat = 0.84
    /// Settings is a compact global overlay. Most of the hit target remains
    /// inside the panel while a small named overlap keeps it attached to the
    /// outer top-right corner.
    static let chromeButtonHitSize: CGFloat = 40
    static let chromeButtonSymbolSize: CGFloat = 20
    static let chromeButtonOutsideOverlap: CGFloat = 0
    static let settingsButtonInset: CGFloat = 10

    // MARK: Settings window
    /// Every pane renders into this one canvas, so selecting a pane never
    /// resizes the window (the native Settings behavior): panes with less
    /// content simply end in empty space, and a pane that outgrows the canvas —
    /// large Dynamic Type, a long localization — scrolls inside it. The height
    /// fits the tallest pane at the default text size and stays well inside a
    /// laptop display's usable height.
    static let settingsPaneWidth: CGFloat = 560
    static let settingsPaneHeight: CGFloat = 540
    static let settingsAboutIconSize: CGFloat = 76
    // The About pane uses a centered product hero while retaining native Form sections.
    static let settingsAboutHeroSpacing: CGFloat = 12
    static let settingsAboutHeroPadding: CGFloat = 10
    static let settingsAboutTitleSpacing: CGFloat = 4
    static let settingsAboutSummaryMaxWidth: CGFloat = 390
    static let settingsAboutLinkSpacing: CGFloat = 8
    static let settingsAboutOpenSourceSpacing: CGFloat = 6
    static let settingsAboutOpenSourcePadding: CGFloat = 4
    // Kept for compatibility with older render/test helpers.
    static let settingsAboutHeaderSpacing: CGFloat = 16
    static let settingsAboutHeaderPadding: CGFloat = 4

    // MARK: Tiles (both appearances)
    /// Preview canvases use this radius for their fixed content and focus ring.
    static let cardCornerRadius: CGFloat = 10
    /// App Icons follows the native switcher idiom: no neutral border, with a
    /// soft rounded selection background around the icon canvas.
    static let iconSelectionPadding: CGFloat = 6
    static let iconSelectionCornerRadius: CGFloat = 18
    /// Preview selection is a single accent-colored plate behind the canvas,
    /// not a border stacked over the image.
    static let previewSelectionPadding: CGFloat = 3

    // MARK: Glass Focus Engine
    /// v2.0 uses one shared moving lens instead of one blur surface per tile.
    /// Selection therefore stays constant-cost as the number of windows grows.
    static let selectionLensInset: CGFloat = 4
    static let selectionLensCornerRadius: CGFloat = 17
    static let selectionLensBorderWidth: CGFloat = 1.2
    static let selectedTileScale: CGFloat = 1.018
    static let selectedTileScaleDuration: TimeInterval = 0.095
    /// The selected item is its own Liquid Glass surface. Even at 100% panel
    /// transparency it keeps a faint accent refraction so selection remains
    /// visible without turning back into an opaque focus plate.
    static let selectionLiquidGlassBaseTintAlpha: CGFloat = 0.08
    static let selectionLiquidGlassDensityTintScale: CGFloat = 0.22
    static let selectionLiquidGlassFallbackFillScale: CGFloat = 0.55
    static var selectionLensStroke: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.58)
    }
    static var selectionLensGlow: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.20)
    }
    static let selectionLensGlowRadius: CGFloat = 12
    /// The glass lens, its glow, and the compositor-only selected-tile scale all
    /// extend beyond the tile frame. NSClipView clips at the document-view
    /// boundary, so the document canvas must reserve this much space on every
    /// edge that is not already protected by a larger close-control overflow.
    static let selectionVisualOverflow: CGFloat = 18

    /// One horizontal rhythm for every row; tiles never manufacture spacing by
    /// changing their own dimensions.
    static let tileSpacing: CGFloat = 14
    /// Full-card separation between wrapped rows. The tile height already
    /// includes preview overlays, title, and metadata; this is the remaining
    /// visual breathing room between complete cards.
    static let tileRowSpacing: CGFloat = 26
    static let tileLabelInset: CGFloat = 8
    /// Native system typography, tuned to the public product preview. Font
    /// family remains AppKit-owned so locale, rendering, and accessibility
    /// continue to follow macOS.
    static let titleFontSize: CGFloat = 14
    static let titleFontWeight: NSFont.Weight = .medium
    static let titleLetterSpacing: CGFloat = -0.08
    static let metadataFontSize: CGFloat = 12
    static let metadataFontWeight: NSFont.Weight = .regular
    static let metadataLetterSpacing: CGFloat = 0
    /// Titles wrap to two lines before truncating; the zone is always two lines
    /// tall so tiles never resize between one- and two-line titles. A single
    /// line centers vertically inside the zone.
    static let titleZoneHeight: CGFloat = 34
    static let titleMaxLines = 2
    static let metadataHeight: CGFloat = 16
    static let labelBottomInset: CGFloat = 10
    static let titleMetadataSpacing: CGFloat = 1
    static let contentTopInset: CGFloat = 8
    /// The one gap between the bottom of the content (icon or preview) and the
    /// top of the title zone — identical on every card, in both appearances.
    static let contentTitleGap: CGFloat = 10

    /// Tile height derived from the content height, so the label zone and the
    /// content-to-title gap stay identical across appearances and screens.
    static func titleY(showMetadata: Bool) -> CGFloat {
        labelBottomInset + (showMetadata ? metadataHeight + titleMetadataSpacing : 0)
    }

    static func tileHeight(contentHeight: CGFloat, showMetadata: Bool) -> CGFloat {
        titleY(showMetadata: showMetadata) + titleZoneHeight
            + contentTitleGap + contentHeight + contentTopInset
    }

    // MARK: App Icons appearance (density matched to the native switcher)
    static let appIconsTileWidth: CGFloat = 116
    static let appIconsContentHeight: CGFloat = 84
    static let largeIconSize: CGFloat = 80

    // MARK: Window Previews appearance
    static let previewsTileWidth: CGFloat = 188
    /// Preview containers all share the aspect ratio of the display the
    /// switcher is presented on, so every card has identical dimensions and
    /// any window fits inside without cropping (unused area uses the semantic
    /// preview surface instead of exposing content behind the panel).
    static func previewContentHeight(width: CGFloat, displayAspect: CGFloat) -> CGFloat {
        (width / max(displayAspect, 0.2)).rounded()
    }
    static let previewCornerRadius = cardCornerRadius
    /// The badge is 60% of its previous rendered size and overlaps the fixed
    /// canvas corner, independent of the source image's aspect-fit bounds.
    static let previewBadgeSize: CGFloat = 38
    static let previewOverlayOverlap: CGFloat = 6
    // MARK: Overlay close control
    static let closeButtonHitSize: CGFloat = 44
    static let closeButtonVisibleSize: CGFloat = 26
    static let closeButtonGlyphSize: CGFloat = 11
    /// The centered control extends beyond the canvas. The panel reuses its
    /// existing padding as clip-safe overflow, so neither cards nor the visible
    /// panel grow to accommodate it.
    static let closeButtonLeadingOverflow = max(
        0, closeButtonHitSize / 2 - tileLabelInset)
    static let closeButtonTopOverflow = max(
        0, closeButtonHitSize / 2 - contentTopInset)
    // MARK: Preview skeleton (while loading or unavailable)
    static let previewFillInFadeDuration: TimeInterval = 0.12
    /// Crossfade used when a fresh capture replaces a cached snapshot mid-session.
    static let previewRefreshFadeDuration: TimeInterval = 0.18
    static let previewSkeletonTitleBarHeight: CGFloat = 17
    static let previewSkeletonInset: CGFloat = 12
    static let previewSkeletonDotSize: CGFloat = 4
    static let previewSkeletonDotSpacing: CGFloat = 5
    static let previewSkeletonLineHeight: CGFloat = 6
    static let previewSkeletonLineSpacing: CGFloat = 8
    static let previewSkeletonLineRadius: CGFloat = 3
    static let previewSkeletonLoadingLineFractions: [CGFloat] = [0.72, 0.88, 0.58, 0.81, 0.66]
    static let previewSkeletonUnavailableLineFractions: [CGFloat] = [0.62, 0.78, 0.48]

    // MARK: Colors
    static var iconSelectionFill: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.12)
    }
    static var iconEmphasisFill: NSColor { .labelColor.withAlphaComponent(0.075) }
    static var previewSelectionFill: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.20)
    }
    static var previewEmphasisFill: NSColor {
        NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.10)
    }
    /// A semantic, adaptive canvas surface makes letterboxing and placeholders
    /// intentional without framing every window with a gray rectangle.
    static var previewSurfaceFill: NSColor {
        NSColor.controlBackgroundColor.withAlphaComponent(0.76)
    }
    static var previewSkeletonChromeFill: NSColor {
        .separatorColor.withAlphaComponent(0.22)
    }
    static var previewSkeletonDotFill: NSColor {
        .tertiaryLabelColor.withAlphaComponent(0.42)
    }
    static var previewSkeletonLineFill: NSColor {
        .tertiaryLabelColor.withAlphaComponent(0.28)
    }
    static var previewSkeletonUnavailableLineFill: NSColor {
        .tertiaryLabelColor.withAlphaComponent(0.16)
    }
    static let settingsVisibilityFadeDuration: TimeInterval = 0.14

    // MARK: Expanded dwell preview
    static let expandedPreviewMinimumWidth: CGFloat = 720
    static let expandedPreviewMinimumHeight: CGFloat = 440
    static let expandedPreviewPanelInset: CGFloat = 24
    static let expandedPreviewTitleHeight: CGFloat = 34
    static let expandedPreviewBadgeSize: CGFloat = 56
    static let expandedPreviewBadgeInset: CGFloat = 10
    static let expandedPreviewCornerRadius: CGFloat = 16
    /// Fallback panel material for macOS 14/15, close to the pre-Tahoe native
    /// switcher; on macOS 26+ the panel uses the system glass effect instead
    /// (see SwitcherPanel), which is what the native switcher draws with.
    static let panelMaterial: NSVisualEffectView.Material = .hudWindow
    /// Overlay controls use the Apple badge idiom (notification/Safari-tab
    /// close): a filled gray circle with a white glyph — legible on any content.
    static var overlayGlyphColor: NSColor { .white }
    static var overlayCircleColor: NSColor { NSColor(white: 0.3, alpha: 0.85) }
}
