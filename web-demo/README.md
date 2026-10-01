# Planora Interactive Demo

This directory contains the browser-based interactive preview for Planora.
It is a static Next.js export deployed to GitHub Pages.

## Current Scope (1.8.4)

Mobile uses an edge-to-edge app viewport; desktop retains a device preview. Includes task creation/editing/completion, search, today/week planning, calendar, appearance, editable name, course details, chronological grade numbers/bars/lines, a timetable, last-seven-day attendance, expandable messages, help search, optional full-sync modules, undo-latest-sync and clearing learning data.

Sync is an explicitly labeled sample-data simulation, not a ManageBac connection. Attendance excludes future/unrecorded lessons and counts late arrivals as attended. Data stays in browser storage; no credentials are requested. Demo JSON task backups are validated and are not native-app backups. Browser graphics approximate the mobile controls; they do not run Apple's Liquid Glass APIs.

## Development

```bash
pnpm install --frozen-lockfile
pnpm dev
```

## Build

```bash
pnpm build
pnpm lint
```
