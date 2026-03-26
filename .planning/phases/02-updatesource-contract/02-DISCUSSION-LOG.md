# Phase 2: UpdateSource Contract - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-26
**Phase:** 2-updatesource-contract
**Areas discussed:** Method signatures, Error boundary

---

## Method Signatures

### Return Type

| Option | Description | Selected |
|--------|-------------|----------|
| UpdateInfo? (Recommended) | null = güncel, UpdateInfo = güncelleme var | ✓ |
| UpdateCheckResult (sealed) | UpToDate / UpdateAvailable(info) — daha explicit | |

**User's choice:** UpdateInfo?

### Hashes Parameter

| Option | Description | Selected |
|--------|-------------|----------|
| String remoteBaseUrl (Recommended) | Engine URL'u geçer, consumer hash çeker | ✓ |
| UpdateInfo fullInfo | Tüm UpdateInfo geçer | |

**User's choice:** String remoteBaseUrl

---

## Error Boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Engine try-catch + map (Recommended) | Engine sarar, bilinmeyen exception'ları UpdateError'a map'ler | ✓ |
| Consumer sorumluluğu | Consumer kendi exception'larını dönüştürür | |

**User's choice:** Engine try-catch + map

---

## Claude's Discretion

- File placement
- Dartdoc examples
- MockUpdateSource structure
- Barrel export strategy
