# User-facing defaults and configurability

## my-alt-tab 3.4.5 external-display + reflow decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Placement-screen preview aspect | Enabled | No | Window Preview cards derive their canvas height from the actual `SwitcherPanel.placementScreen` aspect ratio. External/ultrawide displays never inherit `NSScreen.main` preview geometry. |
| Target-display capture size | Enabled | No | One session capture target is derived from the live target display descriptors; mirrored sessions use the tallest required preview canvas and the sharpest backing scale. |
| Pixel-native screenshot image size | Enabled | No | ScreenCaptureKit results keep their pixel-native `NSImage` logical size instead of being divided by a hard-coded 2x Retina factor, preventing 1x external displays from upscaling captures. |
| Smooth Stable-ID reflow | Enabled | No | Surviving cards, panel, glass, chrome, scroll geometry, controls and focus ring use one 0.52 s non-bouncy ease-out transaction after the 80% dissolve hand-off. |
| Interrupt-safe reflow completion | Enabled | No | Every layout update increments a generation token. An older animation completion may not commit geometry once a newer update has started, eliminating stale-target snaps during rapid removals. |

## my-alt-tab 3.4.4 rapid switching decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Synchronous held-session release | Enabled | No | Releasing Alt/Option returns the event tap from `sessionHeld` to `watching` on the tap thread before the release notification hops to main. |
| Rapid second-chord recognition | Enabled | No | A second Alt/Option+Tab arriving while main is still finishing the prior session is recognized as a fresh `trigger`, never a stale `step`. |
| Immediate committed MRU | Enabled | No | The chosen window moves to MRU index 0 as soon as activation is committed, before asynchronous AX focus confirmation, so the next fast toggle sees the correct current/previous pair. |

## my-alt-tab 3.4.3 bilingual Settings decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Rapid held-session rollover | Enabled | No | Modifier release returns the event tap to watching synchronously. A new Alt/Option+Tab can begin immediately even while main is still finishing the previous session. |
| Immediate activation MRU commit | Enabled | No | The committed target moves to MRU index 0 before asynchronous AX focus confirmation, so the next rapid toggle sees [new current, previous] immediately. |
| Settings language | English | Yes | General → Language; choices are English and 中文. The value is typed/persisted in `Preferences`, applies immediately to the open Settings window, and Restore Defaults returns to English. |
| Live toolbar localization | Enabled | No | Pane labels, hosted pane titles, and the visible Settings window title are relabeled when the language preference changes; no relaunch is required. |
| Settings copy localization | English + Simplified Chinese | No | General, Shortcuts, Windows, Appearance, Updates, About, permission messages, update states, shortcut recorder text, and validation messages use one bilingual table with English fallback for future unknown strings. |
| Tab-count metadata | Off / retired | No | The old Show tab counts row and persisted preference are removed. Old UserDefaults values are ignored and runtime metadata remains off. |
| Liquid Glass help copy | Current Clear Glass model | No | Appearance now describes the real v3.4.2 topology: background-only Clear Glass with independently opaque previews, text, controls, and focus ring. |

## my-alt-tab 3.4.2 click ownership + clear-glass decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Interaction-safe Glass topology | Enabled on macOS 26+ | No | Native `NSGlassEffectView.Style.clear` is background-only. Cards, labels and controls are ordinary sibling views above it, so Glass internals cannot own or swallow their hit testing. |
| Panel click ownership | Enabled | No | The borderless nonactivating `NSPanel` is explicitly key-capable on deliberate clicks, does not ignore mouse events, accepts first mouse, and its root host view has no transparent hit-test holes. |
| Root-level pointer routing | Enabled | No | Window cards, Close, Settings, and permission actions are resolved in `SwitcherPanel.sendEvent` from final host-space rectangles. The global monitor cancels only clicks geometrically outside every visible switcher panel. |
| Literal Liquid Glass transparency | 100% clear | Yes | At 100%, native Clear Glass has no tint, no extra milk, and a background-only surface alpha of about 0.48. Lower percentages restore material strength and add a separate perceptual milk layer. Foreground content remains fully opaque. |
| 96-state erosion pacing | Enabled | No | Compact grayscale+alpha masks use linear temporal spacing and are prewarmed off the close hot path. Pixel erosion finishes one nominal 60 Hz frame before the 80% Stable-ID FLIP hand-off; dust/haze may continue across the hand-off. |

## my-alt-tab 3.4.0 liquid-glass + unified-FLIP decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Liquid ↔ milky glass curve | 100% liquid | Yes | Foreground chrome is now a sibling above the material. 100% sets milk to 0 and native-glass surface alpha to 0.60; lower percentages follow a perceptual `(1-liquid)^1.55` milk curve up to 0.72 while surface alpha rises toward 1.0. Foreground content never fades. |
| Stable-ID unified FLIP reflow | Enabled | No | Removal captures presentation frames by stable window ID, computes final geometry, restores the visible state, then animates NSWindow, material, chrome, scroll geometry, surviving tiles, and the focus ring in one `NSAnimationContext`. The old independent Core Animation tile clock and selected-tile scale animation are removed. |

## my-alt-tab 3.3.0 clear-glass + true-dissolve decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Literal Clear Glass | 100% | Yes | 100% adds **0** neutral density. Lower values linearly add at most 20% content-zone density; the outer macOS 26+ material remains native `NSGlassEffectView.Style.clear` with no tint. |
| True thumbnail erosion | Enabled | No | The original pooled tile is visually hidden after its snapshot is captured, while its geometry remains reserved through the 80% hand-off. A cached 36-frame deterministic fragment-mask atlas actually removes snapshot pixels; a narrow moving emitter follows the same erosion front so dust originates from disappearing image regions. |

## my-alt-tab 3.2.0 80% dust-to-reflow choreography

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Close animation hand-off | 80% dust progress | No | The real AX window closes immediately, but its switcher card remains as a non-interactive visual ghost while erosion/dust plays. Panel size and tile geometry stay frozen until 80% of the 1.02 s dust lifetime (about 0.816 s); only then is the ghost removed and the synchronized 0.42 s panel/tile reflow begins. Reduce Motion skips the delay. |

## my-alt-tab 3.2.0 transparent chrome + focus-ring refinement

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Transparent top chrome | Enabled | No | macOS 26+ uses clear native glass for the outer panel. The user-controlled milky density layer is localized to the window-content region and softly fades out before the reserved ellipsis row, so empty top chrome shows the desktop instead of a white slab. |
| Selection focus | Blue outline | No | Selected tiles receive no fill and no second glass material. One shared moving focus view draws a 2 pt semantic system-blue border with a small blue glow, keeping preview pixels fully visible and preserving O(1) selection updates. |

## my-alt-tab 3.1.0 frosted-glass calibration

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Control Center-style Frosted Glass | 100% | Yes | Keeps the existing 0–100 persistence key, but 100% now means the clearest **frosted** state rather than zero material body. macOS 26+ uses native `NSGlassEffectView.Style.regular` for both the panel and selected-window lens, with a small baseline neutral density, white tint, and thin highlight border. Lower percentages add thickness without fading previews, icons, or labels. |

## my-alt-tab 3.1.0 animation and release refinements

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Smooth shrink cadence | Enabled | No | Panel frame motion and stable-ID tile reflow now share the same non-overshooting cubic timing curve and duration. This removes the perceptual hitch caused by combining AppKit's default resize cadence with a spring. Repeated closes still start from presentation-layer positions. |
| Dense dust erosion | Enabled | No | Replaces the 56 independent particle layers with a compositor-owned `CAEmitterLayer`: three bounded emitter cells produce roughly 300–400 micro-motes during a 0.42 s emission window, while a directional gradient mask erodes the snapshot and a narrow highlight rides the erosion edge. No display link or per-frame CPU loop. |
| Stable TCC release identity | Not available in the 3.1.0 community release | No | 3.1.0 remains ad-hoc signed, so Accessibility / Screen Recording may require re-authorization after an update. The repository retains a future Developer ID + notarization path; enabling it later can provide a stable code identity after one migration authorization. |

## my-alt-tab 3.0.0 motion and update decisions

| Feature | Default | Configurable | Settings / persistence / behavior |
|---|---|---|---|
| Stable-ID list shrink motion | Enabled | No | When an open switcher loses windows, surviving tiles are matched by stable window id and spring from their current presentation-layer positions while the centered panel uses native AppKit frame animation. Reduce Motion disables both. No timer or idle work. |
| Window-close dusting | Enabled | No | One-shot 56-particle fixed budget using deterministic R2 low-discrepancy surface sampling, a gradient erosion mask, and cubic wind paths. No display link, repeating timer, random generator, or idle work. |
| Updates-pane version probe | On pane open | No | Uses Sparkle `checkForUpdateInformation()`, which probes the signed appcast without presenting an up-to-date dialog. The user can invoke the standard verified installer immediately with **Update Now**. Scheduled checks remain controlled by the existing automatic-update preference. |

`Preferences.Defaults` is the only runtime source of persisted defaults. Every typed
user-facing key participates in `Preferences.configurableKeys`, and a regression test
fails when a new configurable key is omitted from Restore Defaults.

## my-alt-tab 2.4.0 decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Liquid Glass transparency | 100% | Yes | Keeps the existing `glassTransparencyPercent` key. v2.4 makes the percentage literal and monotonic: 100% adds zero density, 90% adds 10%, and 0% adds full density. On macOS 26+ the underlying panel and selected-window surfaces use native `NSGlassEffectView.Style.clear`; a separate background-only density layer changes opacity without fading previews, icons, or labels. Older macOS versions retain the native visual-effect fallback. Restore Defaults remains 100%. |

## my-alt-tab 2.3.1 decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Liquid Glass presentation | 100% | Yes | Keeps the existing typed `glassTransparencyPercent` value and 0–100 persistence contract. Rendering now uses a perceptual density curve so 90% is visibly denser than the fully clear 100% endpoint. On macOS 26+ both the panel and selected-window focus lens use native `NSGlassEffectView`; older systems and rasterized test renders use the closest `NSVisualEffectView` fallback. Restore Defaults remains 100%. |

## my-alt-tab 2.3.0 refresh decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Glass transparency | 100% | Yes | Appearance pane; typed `UserDefaults` (`glassTransparencyPercent`) clamped to 0–100. 100% preserves the current native glass, lower values add an adaptive system tint without fading content, changes publish immediately to open switcher panels, and Restore Defaults resets to 100%. |
| Automatic update checks | On | Yes | Updates pane; typed `UserDefaults` through Sparkle's `SUEnableAutomaticChecks` key. Packaged builds start Sparkle against the zhangqiaoran-owned HTTPS appcast; Restore Defaults resets checks to On. |
| Automatic download/install | On | Sparkle-managed | `SUAutomaticallyUpdate` defaults to On. Sparkle verifies every downloadable archive with the embedded EdDSA public key before replacement; the standard Sparkle UI still owns prompts, postponement, and authorization when required. |

## my-alt-tab 1.3.1 decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Switcher shortcut | ⌘Tab | Yes | Shortcuts; typed `UserDefaults`; existing stored values win; resets to ⌘Tab. |
| Open my-alt-tab shortcut | ⌥Tab | Yes | Shortcuts; typed `UserDefaults`; an existing custom or explicitly cleared value wins; resets to ⌥Tab. |
| Show tab counts | Off | Yes | Appearance; typed `UserDefaults`; existing stored values win; resets to Off. |
| Context-sensitive Settings button | Enabled | No | One intended presentation behavior: hidden in cycling until panel hover, always visible in persistent mode. No persistence or reset entry. |
| Complete shortcut interception | Enabled | No | Correctness fix: an owned shortcut must not leak into the native app switcher. No persistence or reset entry. |
| Native title and metadata typography | Enabled | No | Shared required presentation and accessibility behavior. No arbitrary font preference, persistence, migration, or reset entry. |
| Preview skeletons | Enabled | No | Standard loading/fallback presentation. Loading animation follows the mandatory Reduce Motion system setting. No persistence or reset entry. |
| About attribution and website | Shown | No | Application metadata, centralized in `ProjectLinks`; no persistence or reset entry. |
| Restore Defaults | Available | No | Confirmed action rather than a preference. Resets every key in `Preferences.configurableKeys` and never changes permissions, identity, version, or first-run state. |

Existing preferences are never overwritten during an upgrade. Missing keys receive the
centralized default through the registration domain; migrations are explicit and tested.

## my-alt-tab 1.4.0 decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Uniform Settings pane size | Enabled | No | One intended presentation behavior: every pane shares `DesignTokens.settingsPaneWidth`/`settingsPaneHeight`, so selecting a pane never resizes the window. No persistence or reset entry. |
| Selected Settings pane | General | No | Window-state restoration, not a preference: the pane identifier is stored in `UserDefaults` and ignored when unknown. Not part of `configurableKeys`; Restore Defaults leaves it untouched. |
| Unambiguous preview matching | Enabled | No | Correctness fix: a preview is shown only for the window it belongs to, otherwise the tile keeps its placeholder. No persistence or reset entry. |

## my-alt-tab 1.5.0 decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Windows appearing mid-session | Shown | No | Correctness fix: a window the user cannot see is a window they cannot reach, and the existing inclusion policy already decides what qualifies. The stability concern that motivated the frozen list is met by appending instead of reordering (see `SessionListReconciler`), so no legitimate "hide new windows" state remains. No persistence or reset entry. |

## my-alt-tab 1.0.0 (zhangqiaoran release line) decisions

| Feature | Default | Configurable | Settings / persistence / migration / Restore Defaults |
|---|---|---|---|
| Focused multi-display mode | On | Yes | Windows pane; typed `UserDefaults` (`focusedMultiDisplayMode`); one switcher is drawn on the pointer display while eligible windows from every display remain in the list. Turning it off restores the pre-existing placement and cross-display inclusion controls. Restore Defaults resets to On. |
| Switcher placement across displays | All displays | Yes | Windows pane; typed `UserDefaults` (`switcherDisplayPlacement`); no migration — an installation with no stored value takes the new default and every other stored choice is untouched; resets to All displays. Placement is display *behavior*, so it lives beside the inclusion filters rather than under Appearance. |
| Chosen display for "a specific display" | None | Yes | Windows pane; typed `UserDefaults` (`switcherDisplayID`), a display UUID from `CGDisplayCreateUUIDFromDisplayID` so it survives reconnect and reboot. A disconnected choice is kept verbatim, shown in the picker as disconnected, and falls back to the pointer display until it returns; resets to none. |
| Pointer display rather than keyboard focus | Pointer | No | One valid outcome: `NSScreen.main` is documented to misreport the active screen (fullscreen app, or `screensHaveSeparateSpaces` off), and the pointer is what tracks where the user is looking. No persistence or reset entry. See `UPSTREAM.md`. |
| Identical grid on mirrored panels | Enabled | No | Correctness constraint: `SwitcherState` holds one column count for arrow navigation, so per-display grids would make the arrow keys ambiguous. The shared grid comes from the most constrained target display. No persistence or reset entry. |
| Preview row alignment | Center | Yes | Appearance pane; typed `UserDefaults` (`previewRowAlignment`); applies only to incomplete rows in Window Previews mode, so full-row geometry and App Icons remain unchanged. Missing or invalid stored values fall back to Center; Restore Defaults resets to Center. |
| Direct window close | Enabled | No | Delete and the hover close control invoke the selected window's native close action immediately. They never offer application Quit/Force Quit; app-owned unsaved-changes dialogs remain intact. No persistence or reset entry. |
| Event-tap self-healing | Enabled | No | Reliability fix: wake/session recovery first re-enables the existing CGEvent tap and rebuilds it only when invalid or unable to re-enable. No idle polling, timer, persistence, or reset entry. |
