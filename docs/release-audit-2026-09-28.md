# Release audit follow-up

The linked review was treated as a list of hypotheses and checked against source.

## Implemented

- Save helper returns success, rolls back failed transactions, and emits a user-visible error. Notification and undo/curriculum side effects are gated on successful persistence.
- Recurrence advances from the last existing date even when that occurrence is soft-deleted. Future deletion truncates retained rules; restoring a deleted continuing occurrence restores the series rule.
- Explicit course result fields carry authority independently of their value. Unknown parses preserve prior values. Sync-completed tasks carry provenance; manual completions remain independent. Legacy tasks without provenance are conservatively preserved.
- Complete timetable scans carry bounded coverage. Missing rows are removed only inside that range. Partial, unrecognized, malformed, or unscoped scans never trigger removal.
- Attendance summaries carry optional week boundaries; selected-week details use matching summaries only. Home displays recorded history, without mixing a weekly overview into historical totals.
- Background sync compares the captured connection snapshot and connection UUID before import. Interactive connections get a fresh UUID; silent refresh preserves it. This prevents stale results but is not account-level database partitioning.
- Backups use atomic Application Support files. Legacy preferences are removed only after successful migration. Failed writes preserve existing copies.
- Mac display controls use Apple's documented macOS 26 GlassButtonStyle; iOS/iPadOS segmented controls and application navigation are unchanged. Keyboard arrows, selection accessibility, reduced transparency and reduced motion are supported.
- Japanese help articles and localized search are covered by tests.

## Explicit limits

- Database backup snapshots/encoding remain on MainActor to preserve the pre-mutation backup guarantee. Moving this work off-thread needs an asynchronous transaction workflow; this release does not claim that performance redesign.
- A parsed timetable cannot prove the server has published every intended lesson. Reconciliation is limited to a recognized complete table and its date range, never the entire stored history.
- Current date grouping follows the device/WebKit time zone. No school time zone is invented when the site provides none.
- No production school account, installed production app, or personal database is modified by validation. Live school changes and physical in-app update installation remain separate manual checks.
- Hosted native CI is not claimed. Native builds require an installed supported Xcode/SDK; this release uses local xcodebuild test results. No unverified runner label is added.
- Distribution remains ad-hoc signed, not Developer ID notarized.

## Validation

- Production macOS: 132 tests, 6 skips, zero failures. Skips are platform-specific views and the unavailable private migration fixture.
- Production iPadOS 26.5: 133 tests, zero failures.
- Production iOS 27.1: 133 tests, zero failures.
- Vlog macOS: 149 tests, 7 skips, zero failures.
- Vlog iOS 27.1: 26 focused shared tests plus 8 isolation tests, zero failures.
- macOS Release build and deep strict code-signature verification passed.
- Local logs and xcresults are under /private/tmp/planora-audit-1713*, /private/tmp/planora-vlog-1713* and /private/tmp/planora-1713*; these are not release attachments.

## Apple documentation

- https://developer.apple.com/documentation/swiftui/glassbuttonstyle
- https://developer.apple.com/documentation/swiftui/primitivebuttonstyle/glass(_:)
- https://developer.apple.com/documentation/swiftui/pickerstyle/segmented
