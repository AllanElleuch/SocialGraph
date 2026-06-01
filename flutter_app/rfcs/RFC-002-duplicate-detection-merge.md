# RFC-002 — Duplicate Detection & Merge

**Tier:** P1 · **Priority:** 2 · **Depends on:** `U0-model-foundation`

## Summary

Imported address books are full of duplicates. Today import dedupes only by exact
lowercased display name (`main.dart` `_importFromPhone`). Provide fuzzy duplicate
detection and a user-driven merge that combines fields, tags, connections, and
interactions without data loss.

## Work Units

### U2.1 — Duplicate detection engine
- **id:** `U2.1-dup-engine`
- **depends_on:** [`U0-model-foundation`]
- **scope:** `lib/services/duplicate_detector.dart` — pure function
  `findDuplicateGroups(List<Contact>) → List<List<Contact>>`. Scoring: normalized name
  similarity (Levenshtein/Jaro), shared phone/email exact match (strong signal), same
  workplace + first name. Configurable threshold.
- **acceptance_tests:** "Bob Smith" vs "bob smith" grouped; same email different name
  grouped; unrelated contacts not grouped; deterministic ordering.
- **risk_level:** Tier 1 (pure logic).
- **rollback_plan:** delete the service; no callers break (additive).

### U2.2 — Merge function
- **id:** `U2.2-merge-fn`
- **depends_on:** [`U0-model-foundation`, `U2.1-dup-engine`]
- **scope:** `mergeContacts(primary, List<others>) → Contact` using `copyWith`: union of
  tags/connections/interactions, prefer non-empty primary fields, keep earliest `dateMet`
  and latest `lastInteraction`, rewrite `connections` references on other contacts to the
  surviving id.
- **acceptance_tests:** merged tags are a deduped union; earliest dateMet wins; no
  dangling connection ids remain after merge; primary id is preserved.
- **risk_level:** Tier 2 (mutates relationship graph references).
- **rollback_plan:** revert merge service; merges are explicit user actions, no auto-apply.

### U2.3 — Merge review UI
- **id:** `U2.3-merge-ui`
- **depends_on:** [`U2.1-dup-engine`, `U2.2-merge-fn`]
- **scope:** A "Review duplicates (N)" entry that opens a sheet listing candidate groups;
  per group, preview the merged result and Merge / Dismiss. Wire into the import flow as
  a post-import prompt.
- **acceptance_tests:** detecting groups shows the badge count; merging removes the extras
  from the list and persists; dismiss leaves them untouched.
- **risk_level:** Tier 2 (state mutation + persistence path).
- **rollback_plan:** revert UI + the import-flow hook; engine/merge remain dormant.

## Risks / Integration
- Merge rewrites `connections` → must run integration test against GraphView after merge.
- Depends on RFC-004 persistence to make merges durable; if RFC-004 not yet merged, merges
  persist via the existing server/local state path.

## Outputs
- `duplicate_detector.dart`, `contact_merge.dart`, merge-review widget, unit tests for
  detection + merge invariants.
