---
name: keymaster-ui-design
description: Design and refine KeyMaster SwiftUI and AppKit interfaces with concise interaction, modern visual hierarchy, and project-consistent controls. Use for any KeyMaster UI creation, layout change, toolbar, picker, popover, sheet, form, calendar, or visual polish task.
---

# KeyMaster UI Design

Build the smallest complete interface that feels current, direct, and designed.
Preserve native semantics and accessibility without defaulting every visible
surface to legacy system styling.

## Workflow

1. Read the affected view and its interaction flow end to end.
2. Remove controls, labels, menus, and decoration that do not serve the primary
   workflow.
3. Keep persistent navigation outside switched content so layout does not jump.
4. Make common actions direct. Never hide a small option set behind nested
   `Menu` and `Picker` layers; use a segmented control or one custom popover.
5. Define stable dimensions for toolbars, grids, rows, and popovers before
   styling details.
6. Verify empty, populated, selected, disabled, editing, and error states.

## Visual Contract

- Prefer unframed layouts, restrained separators, neutral surfaces, and one
  accent color for state or primary action.
- Use custom plain SwiftUI input surfaces and button styles when `.roundedBorder`,
  `.bordered`, or default `Form` styling makes a focused tool look dated.
- Keep native controls where they carry important platform behavior, including
  dates, permissions, destructive confirmation, and accessibility.
- Use SF Symbols for icon commands and add tooltips to unfamiliar icon buttons.
- Keep corner radii at 8 points or less. Do not nest cards or turn every section
  into a floating panel.
- Match typography to density: compact toolbar and form headings, readable body
  text, no hero-sized labels in utility windows.
- Use explicit grid geometry and directional one-point borders. Never rely on a
  `Divider` overlay to infer vertical versus horizontal direction.
- Give saved calendar items a subtle background and make the entire item a
  direct read/edit target.

## Final Check

Before finishing, search the changed UI for `Menu`, `Picker`, `.roundedBorder`,
`.bordered`, and default `Form` usage. Keep each occurrence only when it is the
clearest native control. Build with `./scripts/dev-run.sh`; leave runtime visual
verification to the user as required by this project.
