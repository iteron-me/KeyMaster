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

### Calendar Todo month grid

The month view uses seven edge-to-edge columns aligned with the weekday header.
Generate the smallest complete-week grid that covers the month, with a minimum
of five rows; do not always render 42 days or divide the available height by six.

```swift
let rowCount = max(5, Int(ceil(Double(leadingDays + dayCount) / 7)))
let days = calendarDays(count: rowCount * 7)
let rowHeight = availableHeight / CGFloat(rowCount)
```

Keep dates in the upper-left, mute adjacent-month dates, and render Todos as
full-width tinted event rows inside the cell. Date/blank-space selection opens
quick add; event-row selection opens the editor and must not also trigger add.
Use localized short weekday names for the main month and very-short names only
for compact year-view mini-months.

Draw directional grid borders with explicit one-point rectangles. Do not use
`Divider` inside an overlay: outside a stack it may keep a horizontal layout
and create stray lines across each day cell.

```swift
Rectangle().frame(height: 1) // horizontal border
Rectangle().frame(width: 1)  // vertical border
```

### Calendar Todo direct controls

The calendar view chooser presents day, week, month, and year directly in one
custom popover. Do not wrap a `Picker` inside a `Menu`; that creates an
unnecessary second interaction layer. Keep Todo import/export controls out of
the calendar toolbar.

Task add and edit forms use plain text controls inside restrained custom
surfaces. Quick add has one accent Add action. Edit places a destructive Delete
opposite the accent Save action; neither form needs a redundant Cancel button
because Esc and normal popover dismissal already close without saving. Retain
the native `DatePicker` because its date semantics and accessibility are useful.

Make the entire visible Todo event row the editor button in day, week, and month
views. Attach the edit popover to that row, not the calendar root, and use
`arrowEdge: .trailing` so the editor opens immediately to the row's right. This
edge is verified against this app's macOS runtime behavior; `.leading` places
the popover on the left.

```swift
TextField("Task title", text: $title)
    .textFieldStyle(.plain)
    .background(CalendarTodoFormStyle.fieldBackground)

Button("Save", action: save)
    .buttonStyle(CalendarTodoFormButtonStyle(isPrimary: true))
```

---

## Common Mistakes

<!-- Component-related mistakes your team has made -->

(To be filled by the team)
