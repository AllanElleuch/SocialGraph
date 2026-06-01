# RFC-004 — Cloud Sync & Backup

**Tier:** P1 · **Priority:** 4 · **Depends on:** `U0-model-foundation`

## Summary

The #1 trust feature: "I won't lose my contacts." Today there is **no local persistence** —
`ContactService` is HTTP-only to `localhost:3000` with an in-memory seed fallback, so
offline edits vanish on restart. This RFC delivers a local-first repository, JSON
backup/restore (export/import a vCard-adjacent JSON file), and reconciliation against the
existing Express backend.

> **Scope honesty:** True hosted multi-device sync requires a backend choice + auth
> (Firebase / Supabase / the existing Express server behind auth). This RFC implements the
> **local-first foundation + backup/restore + single-backend reconciliation**. Hosted,
> authenticated, multi-device sync is split into a follow-on unit (U4.4, deferred) gated on
> a backend decision.

## Work Units

### U4.1 — Local-first persistence layer
- **id:** `U4.1-local-store`
- **depends_on:** [`U0-model-foundation`]
- **scope:** Add `shared_preferences` (or `path_provider` + JSON file). Create
  `lib/services/contact_repository.dart` wrapping load/save of the full contact list to
  disk. `main.dart` reads from the repository first (instant cold start), then refreshes
  from the server in the background.
- **acceptance_tests:** contacts added offline survive an app restart; cold start renders
  from cache before network completes; corrupt cache falls back to seed without crashing.
- **risk_level:** Tier 2 (new storage dependency + load path).
- **rollback_plan:** revert repository + `main.dart` wiring; app reverts to server/seed.

### U4.2 — Backup export / import
- **id:** `U4.2-backup`
- **depends_on:** [`U4.1-local-store`]
- **scope:** Export all contacts to a shareable JSON file and import/merge from one.
  Reuse RFC-002 merge to avoid duplicate explosion on import.
- **acceptance_tests:** export→import round-trips losslessly; importing an overlapping file
  merges rather than duplicates.
- **risk_level:** Tier 1.
- **rollback_plan:** revert backup service + its UI entry.

### U4.3 — Sync reconciliation
- **id:** `U4.3-reconcile`
- **depends_on:** [`U4.1-local-store`]
- **scope:** Reconcile local cache ↔ server on refresh: last-write-wins by a
  `updatedAt` timestamp (added in U0 or here), queue offline mutations and flush when the
  server is reachable.
- **acceptance_tests:** an offline edit flushes to the server on reconnect; server-newer
  record wins; no duplicate creation across sync cycles.
- **risk_level:** Tier 3 (conflict resolution + data integrity).
- **rollback_plan:** disable reconciliation flag; local store + server calls still work
  independently.

### U4.4 — Hosted multi-device sync *(DEFERRED — needs backend decision)*
- **id:** `U4.4-hosted-sync`
- **depends_on:** [`U4.3-reconcile`, external: auth/backend choice]
- **scope:** Auth + per-user cloud store. **Not implemented this pass.**
- **risk_level:** Tier 3.
- **rollback_plan:** n/a (not built).

## Risks / Integration
- Underpins durability for RFC-002 merges and RFC-003 logs — merge U4.1 early.
- Conflict resolution (U4.3) is the highest-risk unit; ships behind a flag.

## Outputs
- `contact_repository.dart`, backup service + UI, reconciliation logic, persistence tests.
