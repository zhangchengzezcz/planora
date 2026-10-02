# Task detail navigation — 1.8.12 (45)

## Changes

- Mac task double-click and the context-menu detail action now push the shared TaskDetailView inside NavigationStack.
- Removed the task inspector and task-detail sheet. Table selection remains local and supports bulk actions; external task routes open the full page.
- Returning clears the external route so the same pinned/menu-bar task can be requested again.
- The shared Mac detail content is centered with an 860-point maximum width. The main application navigation sidebar remains available.
- Pin/Edit belong to the displayed detail, not a selected row behind it.

## Verification

- Dedicated source export excluded all unfinished entrance/onboarding changes.
- Full macOS suite: 166 tests, 6 skipped, 0 failures. Skips: five UIKit-only rendering checks and one unavailable private legacy-store fixture.
- Updated a stale menu-bar icon test from the former 19-point width to the existing 22×18 asset dimensions; no icon implementation changed.
- Native hosting screenshots inspected at wide and narrow widths; task workspace renders the detail in its main content area. Tests assert no task-detail sheet and unchanged data after resizing.
- macOS Release and generic iOS Simulator builds succeeded. This run did not execute the iOS test suite.
- Deep/strict code-signature verification and DMG structural verification passed. Sparkle feed and update archive signatures verified during packaging.
- Native AppKit toolbar constraint warnings still appear at narrow test window sizes. An end-to-end physical double-click, Back and Edit UI pass is not claimed; the desktop was shielding accessibility during the test run.
- Distribution remains ad-hoc signed, not Apple-notarized. No installed application or user database was replaced for verification.

## Local evidence

- `/tmp/planora-1812-mac-tests-final.log`
- `/tmp/planora-1812-verified/Logs/Test/`
- `/tmp/planora-1812-release.log`
- `/tmp/planora-1812-ios.log`
- `/tmp/planora-1812-dmg.log`
- `/tmp/planora-1812-distribution/`
