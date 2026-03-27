---
phase: 05-ui-removal
plan: 02
subsystem: documentation
tags: [changelog, migration-guide, breaking-change, v2]
dependency_graph:
  requires: [05-01]
  provides: [v2-migration-docs]
  affects: []
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - CHANGELOG.md
decisions:
  - "CHANGELOG.md is the primary migration document — consumers can migrate without reading source code"
  - "v2.0.0 entry structured with removed-symbols table + 3-step migration guide matching plan spec exactly"
metrics:
  duration: "1m"
  completed: "2026-03-27"
  tasks_completed: 1
  files_changed: 1
---

# Phase 05 Plan 02: v2.0.0 CHANGELOG Migration Guide Summary

## One-liner

v2.0.0 CHANGELOG entry with removed-symbols table and before/after migration examples for DesktopUpdaterController → checkForUpdate/downloadUpdate/applyUpdate transition.

## What Was Built

Prepended a complete v2.0.0 section to `CHANGELOG.md` that documents all breaking changes from the Phase 05-01 UI removal. The section follows the exact structure specified in the plan:

1. **Breaking change headline** — announces the package is now a headless engine
2. **Removed symbols table** — 11 removed classes/types with reasons (DesktopUpdater, DesktopUpdaterController, 4 widget types, DesktopUpdateLocalization, 3 model types, FileHashModel, UpdateProgress v1)
3. **Migration guide** in 3 steps:
   - Step 1: Implement UpdateSource (with full before/after code)
   - Step 2: Use checkForUpdate / downloadUpdate / applyUpdate function-based API (with exhaustive switch on UpdateCheckResult)
   - Step 3: Remove widget imports
4. **Complete import change** showing single-import migration

All existing changelog entries (## 1.3.0 through ## 1.0.0) are preserved intact after the v2.0.0 block.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Write v2.0.0 CHANGELOG migration section | 5c10f67 | CHANGELOG.md |

## Verification Results

- PASS: `## 2.0.0` at top of file (first line)
- PASS: 9 occurrences of checkForUpdate/downloadUpdate/applyUpdate/UpdateSource
- PASS: DesktopUpdaterController, DesktopUpdateWidget, FileHashModel all present in removed-symbols table
- PASS: Prior entries (## 1.3.0 through ## 1.0.0) preserved intact

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The CHANGELOG.md is a documentation file — all migration examples reference actual v2 API names confirmed from `lib/src/desktop_updater_api.dart`.

## Self-Check: PASSED

- CHANGELOG.md exists and leads with `## 2.0.0`: confirmed
- Commit 5c10f67 exists: confirmed
