# Component Guidelines

> How components are built in this project.

---

## Overview

<!--
Document your project's component conventions here.

Questions to answer:
- What component patterns do you use?
- How are props defined?
- How do you handle composition?
- What accessibility standards apply?
-->

(To be filled by the team)

---

## Component Structure

<!-- Standard structure of a component file -->

(To be filled by the team)

---

## Props Conventions

<!-- How props should be defined and typed -->

(To be filled by the team)

---

## Styling Patterns

<!-- How styles are applied (CSS modules, styled-components, Tailwind, etc.) -->

(To be filled by the team)

---

## Accessibility

<!-- A11y requirements and patterns -->

### Screen overlay keyboard tools

Screen-wide tool overlays, such as Screenshot Area and Screen Navigation, should
capture only the keys that are part of the active tool contract and leave the
rest to AppKit. For Screen Navigation, the active contract is:

- `Esc` cancels and closes all overlay windows.
- `Backspace` edits the typed hint prefix.
- `A` through `Z`, ignoring Shift/Caps Lock, extend the hint prefix.
- `↑` / `↓` scroll the original foreground app and keep the overlay active.

Screen Navigation overlays must not become the key window just to capture hint
input. Keep the original foreground app active and use a short-lived
`CGEventTap` session monitor for the navigation contract instead:

- consume `Esc`, `Backspace`, and hint letters in the session monitor;
- let `↑` / `↓` pass through to the original foreground app so apps that already
  scroll with arrow keys keep their normal routing;
- keep overlay windows visual-only (`ignoresMouseEvents = true` and
  `canBecomeKey == false`).

Avoid using a key overlay window plus synthetic scroll events as the primary
scroll path. In practice this can leave KeyMaster as the keyboard target and make
Chrome-like apps appear unscrollable even though mouse scrolling still works.
Mark any remaining synthetic fallback events with
`KeyboardEventEngine.syntheticEventMarker` so the shortcut engine can ignore them.

### Non-activating command palettes

Application menu search uses a borderless `.nonactivatingPanel` whose
`canBecomeKey` is `true`: KeyMaster receives text input while the captured target
application remains frontmost. Preserve these presentation contracts:

- An empty query shows only the single material-backed search row.
- A non-empty query expands the real window frame downward; keep the window's
  `frame.maxY` fixed so the search row does not move.
- Keep all ranked matches in a lazy scroll view, display at most eight rows at
  once, and scroll arrow-key selection into view.
- Keep menu-command rows icon-free and render native shortcuts as plain trailing
  metadata. Layer a translucent white tint over `ultraThinMaterial` for the
  Spotlight-like surface, and use a rounded neutral primary-color wash for the
  selected row instead of a saturated accent fill.
- Center the collapsed row horizontally at the Spotlight-like upper-middle
  screen position, leaving enough space below for the bounded result list, and
  use half the row height as the surface corner radius.
- Put application identity, loading, and failure status inside the search row.
  Do not add separate header, search-field, or result-area surface backgrounds.
- `Esc`, outside click, target-app switch, and successful execution close the
  panel through the shared controller close path.
- Non-activating panels handle Return, numeric-keypad Enter, arrows, and Esc in
  an AppKit local key monitor scoped to the panel's window number. Pass all
  other keys through to the focused `TextField`; SwiftUI `onKeyPress` and
  `onSubmit` are not reliable submission boundaries for this panel style.

Regression checks must assert that empty-query height stays equal to the search
row height and that non-empty result heights are bounded by the visible-row
limit even when more matches are available.

```swift
paletteShape.fill(.ultraThinMaterial)
    .overlay { paletteShape.fill(Color.white.opacity(0.52)) }
```

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

(To be filled by the team)
