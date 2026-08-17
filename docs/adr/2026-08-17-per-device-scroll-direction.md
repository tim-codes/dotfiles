# ADR: Per-device scroll direction — LinearMouse for non-Logi mice, Logi Options+ for MX mice

Date: 2026-08-17
Status: Accepted

## Context

macOS cannot reverse scroll direction for mice independently of the trackpad.
The "Natural Scrolling" toggles shown under both the Mouse and Trackpad panes
are the same underlying preference (`com.apple.swipescrolldirection`), so
flipping one flips both. Logi Options+ solves this for Logitech MX mice via its
own driver, but non-Logitech mice were left with trackpad-style scrolling.

A third-party utility is needed for the non-Logi mice. Options+ must keep
running alongside it for everything else it does (SmartShift, buttons, per-app
profiles), which constrains the choice: Options+ intercepts scroll input from
Logi devices and re-posts synthesized events, and anything downstream in the
event chain processes those.

## Options considered

| | Feature breadth | Footprint | Maintenance | Options+ coexistence |
|---|---|---|---|---|
| Scroll Reverser | Reverse per input type / axis only | Tiny | Dormant (last release Mar 2022, still works) | Options+ smooth scrolling makes MX events look continuous/trackpad-like, so its mouse-vs-trackpad classification can misfire on Logi devices |
| LinearMouse | Per-device + per-app scroll, pointer speed, button remaps | Small | Active (v0.11.4, Aug 2026) | Safe if scoped to reversal only; its scroll speed/smoothing settings apply globally and stomp Options+ per-app scroll config ([#346](https://github.com/linearmouse/linearmouse/issues/346)) |
| Mos | Reverse + smooth scrolling | Heaviest (continuous interpolation) | Slower cadence | Worst fit: two smoothing engines on one event stream → double-acceleration, stutter |
| UnnaturalScrollWheels | Invert discrete wheel events only | Tiny | Infrequent releases | Structurally can't clash (ignores continuous events) but may also miss any mouse whose driver smooths scrolling |

## Decision

**LinearMouse**, with its "Bypass events from other applications" setting
enabled so it never touches events synthesized by Logi Options+. Division of
labor:

- **Logi Options+** keeps owning the MX mice entirely — scroll direction
  (its override stays *enabled*), SmartShift, buttons, per-app profiles.
- **LinearMouse** reverses vertical scrolling for every other mouse.
- **macOS stays on "natural"** so the trackpad is untouched by both.

An explicit Logitech vendor-exclusion scheme (`vendorID: 0x46d`) was the
original plan, but the bypass toggle supersedes it: Options+ consumes raw MX
input and re-posts synthesized events, and with bypass on LinearMouse ignores
exactly those. No per-vendor config needed, and it also neutralizes the
virtual-device attribution caveat below.

Chosen because it is the only actively maintained option with per-device
config, its footprint matches the minimal tools, and it leaves headroom
(per-app tweaks, button remaps for non-Logi gear) without adopting any of it
now. The exclusion is declarative rather than "remember not to configure that
device."

## Implementation

- `linearmouse` cask in `scripts/brew-update`.
- Config stowed from `src/.config/linearmouse/linearmouse.json`: reverses
  vertical scroll for `category: mouse` (trackpads never match). The JSON is
  LinearMouse's single source of truth for schemes — its GUI reads and writes
  this same file and live-reloads on change, so per-device settings are fully
  declarative from the repo.
- App-level settings (the General pane: bypass, menu bar, dock, update
  channel) are **not** in the JSON — they persist in the
  `com.lujjjh.LinearMouse` UserDefaults domain. `scripts/setup-macbook`
  codifies them with `defaults write` (before first launch), adds a login
  item ("Start at login" is SMAppService state, not a plist key), and
  launches the app. The menu-bar mode values are JSON-encoded strings, so
  the embedded quotes in those `defaults write` lines are load-bearing.
- The all-mice scheme also carries smoothing and universalBackForward
  (originally tuned per-device on a Corsair mouse, then generalized). Global
  scrolling modification was the flagged conflict surface with Options+, but
  the bypass toggle covers it: MX events arrive pre-synthesized and are
  ignored. If an MX mouse ever feels double-smoothed, check the bypass toggle
  first.
- First launch requires granting Accessibility permission (event tap). TCC
  blocks scripting this without MDM, so it is the one manual click per
  machine.

## Caveats

- The bypass toggle makes coexistence depend on Options+ actually re-posting
  events. If Options+ is not running, MX mice deliver raw events, which
  LinearMouse will then reverse — which is the desired behavior anyway, since
  Options+'s own reversal is absent in that state.
- If a non-Logi vendor's driver also synthesizes events, bypass will skip
  those too; per-device schemes in the JSON are the fallback lever.
