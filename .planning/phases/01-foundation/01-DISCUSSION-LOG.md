# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-26
**Phase:** 1-foundation
**Areas discussed:** Model naming & structure, Error type design, Version comparison, File organization

---

## Model Naming & Structure

### Model Implementation

| Option | Description | Selected |
|--------|-------------|----------|
| Manual (Recommended) | El ile yazılmış final class'lar — plugin'e code-gen bağımlılığı eklenmez | ✓ |
| freezed + json_serializable | Code generation ile immutable modeller — build_runner gerektirir | |

**User's choice:** Manual
**Notes:** Plugin dependency footprint minimal kalmalı

### Model Naming

| Option | Description | Selected |
|--------|-------------|----------|
| Clean names (Recommended) | UpdateInfo, FileHash, UpdateProgress — suffix yok | ✓ |
| Model suffix | UpdateInfoModel, FileHashModel — mevcut convention | |

**User's choice:** Clean names

### JSON Serialization

| Option | Description | Selected |
|--------|-------------|----------|
| Sadece FileHash için (Recommended) | Engine hashes.json okur/yazar, UpdateInfo consumer oluşturur | ✓ |
| Tüm modellerde | Her modelde fromJson/toJson | |

**User's choice:** Sadece FileHash için

---

## Error Type Design

### Error Detail Level

| Option | Description | Selected |
|--------|-------------|----------|
| Message + cause (Recommended) | Her subtype message String ve opsiyonel Object? cause taşır | ✓ |
| Sadece message | Minimal — sadece String message | |
| Typed fields per subtype | Her subtype farklı alanlar taşır | |

**User's choice:** Message + cause

### Error Subtypes

| Option | Description | Selected |
|--------|-------------|----------|
| Bu 5 subtype yeterli | NetworkError, HashMismatch, NoPlatformEntry, IncompatibleVersion, RestartFailed | ✓ |
| SandboxError da ekle | App Sandbox için özel error type | |

**User's choice:** 5 subtype yeterli

---

## Version Comparison

### Comparison Method

| Option | Description | Selected |
|--------|-------------|----------|
| int buildNumber (Recommended) | Mevcut yaklaşım — basit integer karşılaştırma | ✓ |
| Semver string comparison | version string'i semver olarak parse edip karşılaştırır | |
| Consumer karar versin | UpdateSource'a shouldUpdate metodu ekle | |

**User's choice:** int buildNumber

### getCurrentVersion() Return Type

| Option | Description | Selected |
|--------|-------------|----------|
| int buildNumber (Recommended) | Native'den build number int olarak döner | ✓ |
| String version | Tam version string döner | |

**User's choice:** int buildNumber

---

## File Organization

### Directory Structure

| Option | Description | Selected |
|--------|-------------|----------|
| Alt klasörlerle (Recommended) | lib/src/models/, lib/src/errors/, lib/src/engine/ | ✓ |
| Düz lib/src/ | Hepsi lib/src/ altında düz | |
| Feature-based | lib/src/update_check/, lib/src/download/ | |

**User's choice:** Alt klasörlerle

---

## Claude's Discretion

- copyWith() implementation details
- @immutable annotation usage
- Field order in constructors
- UpdateCheckResult constructor style

## Deferred Ideas

None
