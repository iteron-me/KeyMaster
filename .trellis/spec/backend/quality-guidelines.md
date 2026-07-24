# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

<!-- Patterns that must always be used -->

(To be filled by the team)

### Accessibility menu execution

- Menu scanning stores searchable metadata plus a session-local
  `UUID -> (child indexes, original title)` locator; it does not persist menu
  data or execution actions.
- Do not execute an `AXUIElement` retained from the scan. Apps such as Android
  Studio rebuild their accessibility menu trees, and a stale element can return
  success without invoking the command.
- On execution, follow the stored child indexes from a fresh `AXMenuBar`, reject
  the command if the original title no longer matches, then read the fresh
  item's supported actions. Prefer `kAXPickAction`, and use `kAXPressAction`
  only when Pick is unavailable.
- Do not infer executability from the role alone. A leaf must expose one of the
  supported execution actions before it enters search results.
- Exclude the system-owned Apple menu only when the top-level item has the
  `AXMenuBarItem` role, `Apple` title, and no identifier; do not drop the first
  menu by position because the next item is the application's own menu.
- Unit tests must cover Pick preference, Press fallback, and rejection when
  neither action is available.

Wrong:

```swift
elementsByID[id] = scannedElement
AXUIElementPerformAction(elementsByID[id]!, kAXPickAction as CFString)
```

Correct:

```swift
locatorsByID[id] = (childIndexes, originalTitle)
let currentElement = resolve(childIndexes, from: freshMenuBar)
guard title(of: currentElement) == originalTitle else { return false }
```

---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
