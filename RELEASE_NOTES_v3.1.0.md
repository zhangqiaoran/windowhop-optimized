# my-alt-tab v3.1.0

**Author / maintainer / release owner: zhangqiaoran**

## Frosted Glass calibration

v3.1.0 shifts the switcher away from a mostly clear glass treatment and toward the
milky, blurred material visible in macOS Control Center.

- macOS 26+ uses native `NSGlassEffectView.Style.regular` for the panel and selected-window lens.
- 100% remains the clearest user setting, but it still keeps a visible frosted body and blur.
- Lower percentages make the glass progressively denser and grayer without fading previews,
  icons, titles, or controls.
- A thin rounded white highlight rim and softer neutral selection treatment complete the material.

## Smoother window-list shrink

The previous animation mixed AppKit's built-in animated window resize with a separate
`CASpringAnimation` for surviving cards. Those two motion curves did not share the same
velocity profile, which could look like a dropped frame even when rendering stayed smooth.

v3.1.0 makes the panel frame, surviving windows, and selection lens share one bounded,
non-overshooting cubic curve.

- Duration: about **0.42 s**.
- Repeated fast closes still begin from Core Animation presentation-layer positions.
- No spring overshoot or secondary oscillation.
- Reduce Motion remains honored.

## Reference-driven dust dissolution

The close effect was reworked after reviewing the supplied reference video.

- The window surface is progressively removed with a directional gradient erosion mask.
- A narrow illuminated edge travels with the erosion front.
- A compositor-owned `CAEmitterLayer` replaces dozens of independently animated particle layers.
- Four bounded emitter cells create roughly **300–400** visible micro-particles and haze motes
  during the short emission phase.
- Tiny sharp dust, regular fragments, subtle accent glints, and large low-alpha haze combine
  into a drifting dust cloud rather than a simple burst.
- The actual target window still closes immediately; the dissolve is only a non-blocking visual residual.
- No display link, no repeating particle timer, and no per-frame CPU simulation.

## Signing and macOS permissions

This 3.1.0 community release remains **ad-hoc signed**, because no Apple Developer
Developer ID certificate is configured for the project.

Sparkle still verifies the downloaded archive with the existing my-alt-tab EdDSA update key,
so in-app update integrity remains protected. However, macOS privacy permissions such as
Accessibility and Screen Recording may need to be granted again after replacing an ad-hoc build.

The repository keeps a documented future path for stable Developer ID signing and Apple
notarization. If that is enabled later, the first migration may require one final authorization;
subsequent releases can then retain a stable macOS code identity.

## Build

- Marketing version: **3.1.0**
- Internal build: **30100**
- Minimum macOS: **14.0**
- Bundle ID: `com.zhangqiaoran.myalttab`
