# my-alt-tab v2.0.0 — Glass Focus Engine

**Author / maintainer / release owner: zhangqiaoran**  
Release date: 2026-09-06

v2.0 starts a new visual product line for my-alt-tab: **more premium focus feedback with less duplicated compositor work**.

## Product architecture

A naive glass thumbnail interface creates an independent blur/effect surface for every card. It looks good with five windows and scales poorly with fifty.

my-alt-tab 2.0 instead uses:

- one shared native glass surface for the switcher;
- one shared moving Focus Lens;
- at most two tile transforms when selection changes;
- no per-thumbnail blur stack;
- no idle or looping focus animation.

The visual system gets richer while selection work stays independent of list size.

## Glass Focus Engine

### Shared Glass Plane

On macOS 26+, the panel uses Apple's native `NSGlassEffectView`. On macOS 14/15, AppKit's `NSVisualEffectView` provides the native fallback.

### Single Focus Lens

One semantic accent lens follows the selected thumbnail. Target frames are cached when grid layout is built, so each next target is resolved by direct array index.

**Selection geometry lookup: O(1).**

### Optical Lift

The selected thumbnail receives a 2.2% compositor transform. The old selected tile returns to 1.0 and the new tile moves to 1.022.

No card is remeasured. No title is rebuilt. No full-grid layout runs.

### Distance-Adaptive Motion

A pure constant-time planner computes transition duration from row/column distance:

- adjacent Cmd-Tab steps remain fast;
- longer arrow-key jumps get slightly more travel time;
- duration is capped at 155 ms;
- Reduce Motion makes the transition immediate.

Rapid input retargets from the current Core Animation presentation state instead of queuing stale motion.

## Performance model

| Path | v2.0 strategy |
|---|---|
| Selection | O(1) old/new tile update |
| Focus motion | one lens, constant number of animations |
| Lens geometry | cached frame array, O(1) lookup |
| Preview delivery | hash-indexed IDs |
| Preview refresh | O(n), zero sort |
| Preview matching | PID buckets + flat score matrix + dense masks |
| Capture scheduling | session in-flight deduplication |
| EventTap hot path | 128-bit bitset for normal keycodes |
| Preview memory | byte-bounded ~64 MiB cache |
| Hidden views | transient images released |
| Multi-display routing | O(display count), evaluated at open time |

## UI rules

- clearly visible selected state in Light and Dark Mode;
- no per-card drop shadow;
- no infinite skeleton/shimmer;
- no high-frequency mouse polling;
- no background polling;
- 44×44 close target retained;
- left / center / right incomplete-row alignment retained;
- accessibility Reduce Motion remains authoritative.

## Multi-display

Focused multi-display behavior is retained:

- show the switcher only on the display containing the pointer;
- keep eligible windows from every display in the candidate list;
- resolve pointer placement only when opening the switcher.

## Identity

- Product: **my-alt-tab**
- Version: **2.0.0**
- Build: **20000**
- Bundle ID: `com.zhangqiaoran.myalttab`
- Author / maintainer / release owner: **zhangqiaoran**
- License: GNU GPL-3.0

Inherited GPL attribution remains in `UPSTREAM.md` and `LICENSE`.
