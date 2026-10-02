# Task Toolbar Regression Verification: 1.8.13

## Scope

Restore single-selection editing and the unified Mac task toolbar without
reintroducing an inspector or changing the full-page layout from 1.8.12.
The main window owns the editor and Pin action. Active detail views and single
table selections publish their task ID; the persisted `deletedDate` predicate
excludes deleted tasks. The unified-toolbar environment belongs to the entire
NavigationSplitView so pushed destinations inherit it.

## Verified

- Clean macOS Release build: passed.
- Clean iOS Simulator build: passed.
- MacMenuBarTests and MacTaskLayoutTests: 12 tests, zero failures.
- New hosted regression verifies detail task identity reaches the parent toolbar.
- Home task detail: icon-only Edit opens the matching task; canceled without saving.
- Single selected table row: Edit remains visible and opens the matching task.
- Double-click selected task: full-page details, not an inspector or detail sheet.
- Back from task detail: table selection and Edit remain available.
- Visible toolbar: Messages, Profile and Edit grouped on the right; one Pin centered.
- Existing unfinished entrance-animation files are excluded from the release.

## Limits

The final multi-selection UI check was interrupted by screen lock. The code
publishes a table task ID only for exactly one selected row. This release does
not rerun real-account sync flows or the complete cross-platform test suite.
The Mac package is ad-hoc signed, not Apple-notarized.
