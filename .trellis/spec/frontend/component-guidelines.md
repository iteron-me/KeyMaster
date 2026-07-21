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

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

(To be filled by the team)
