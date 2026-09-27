# Maintenance review: 1.7.12

## Scope

Repository-wide searches covered unsafe operations, forced failures, duplicate-key dictionaries, network entry points, API availability and release scripts. Detailed review focused on persistence, import and synchronization, task deletion/undo, recurrence, reminders, avatars, grade presentation and attendance. This is a maintenance review, not a claim that every possible defect has been eliminated.

Uncommitted entrance-animation work and the separate Vlog project are excluded from the production release. User databases and installed applications are not modified by the review.

## Changes

- Ignore a valid, unrelated `default.store`; still report corrupt databases. Migration never mutates the source database.
- Reject invalid cached ManageBac hostnames before URL construction. Invalidate background work when the connection is removed or changes schools.
- Serialize notification mutations across suspension points. Fetch pending/delivered notifications once per batch deletion rather than once per task.
- Reject unsupported reminder dates, invalid clock components and overflowing day offsets. Protect recurrence sequence arithmetic against overflow.
- Tolerate duplicate identifiers when restoring deleted tasks and update the restoration index after insertion.
- Encode avatars before atomically replacing the existing file.
- Keep non-finite scores out of chart/percentage calculations.
- Lazily construct grade bars with a fixed cross-axis height; group attendance lessons once per view evaluation.
- Consolidate single-task deletion through the batch implementation and remove two unused reminder wrappers.

## API review

Deployment targets remain iOS/iPadOS 26 and macOS 26. The installed Xcode SDKs compile the 27-specific paths. The existing availability checks around `swipeActionsContainer()` remain in place, with `List` handling swipe coordination on 26. Native segmented pickers are retained. No unsupported API substitution or language-mode migration was made merely to increase version numbers.

Official references:

- [Swipe action containers](https://developer.apple.com/documentation/swiftui/view/swipeactionscontainer())
- [SwiftUI performance](https://developer.apple.com/documentation/xcode/understanding-and-improving-swiftui-performance)

## Verification and limits

Regression coverage includes unrelated/corrupt legacy databases, invalid reminders, serialized asynchronous operations, recurrence overflow, hostname injection and non-finite grades. Existing suites cover ManageBac parsing/import, recurrence, task operations, backups, ordering and layout, including thousand-task rendering on iOS.

Completed runs: macOS, 122 tests with 6 skips and no failures; iPadOS 26.5, 123 tests with no failures; iOS 27.1, 123 tests with no failures. The signed Release configuration builds successfully. Packaging scripts pass shell syntax validation and the final DMG passes remounted structural verification.

The private historical database fixture was unavailable. Its test skips without touching user data. Five UIKit rendering tests skip on macOS and run on iOS instead. The macOS narrow-window test still emits a framework toolbar-title constraint warning while its sizing assertions pass; no private-framework workaround was introduced.

The release uses the existing vendored Sparkle framework and signed appcast process. DMG verification checks that the image and Finder metadata are embedded inside the mounted volume. Packaging checks do not replace testing an update on another physical Mac. The application is ad-hoc signed, not Developer ID notarized.
