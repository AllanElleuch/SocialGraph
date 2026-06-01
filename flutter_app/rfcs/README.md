# SocialGraph RFC Set — Recommended Build Order

RFCs generated with the **ralphinho-rfc-pipeline** pattern: each feature is decomposed
into independently verifiable **work units** with `id`, `depends_on`, `scope`,
`acceptance_tests`, `risk_level`, and `rollback_plan`. Units flow through the per-unit
quality pipeline (research → plan → implement → test → review → merge-ready) and a
merge queue with integration verification.

Source analysis: [`../CONTACT_MANAGER_FEATURES.md`](../CONTACT_MANAGER_FEATURES.md).

## RFC Index

| RFC | Feature | Tier | Priority |
|-----|---------|------|----------|
| [RFC-001](./RFC-001-search-and-quick-actions.md) | Search + tap-to-call / text / email | P0 | 1 |
| [RFC-002](./RFC-002-duplicate-detection-merge.md) | Duplicate detection & merge | P1 | 2 |
| [RFC-003](./RFC-003-notes-and-interaction-logging.md) | Notes + interaction logging | P1/P2 | 3 |
| [RFC-004](./RFC-004-cloud-sync-and-backup.md) | Cloud sync & backup | P1 | 4 |
| [RFC-005](./RFC-005-stay-in-touch-reminders.md) | Stay-in-touch reminders | P2 | 5 |
| [RFC-006](./RFC-006-relationship-strength.md) | Relationship strength scoring | P2 | 6 |

## Cross-RFC Dependency DAG

```
                 ┌─────────────────────────────────────┐
                 │ U0  Foundation: Contact.copyWith +   │
                 │     phone/email/notes/interactions   │  (shared model layer)
                 └───────────────┬─────────────────────┘
            ┌────────────┬───────┴───────┬───────────────┬──────────────┐
            ▼            ▼               ▼               ▼              ▼
       RFC-001       RFC-002         RFC-003          RFC-004        (UI shell)
   search+actions   dedupe/merge   notes+logging   persist+sync
            │                          │                │
            │                          ▼                │
            │                     ┌─────────┐           │
            └────────────────────▶│ RFC-006 │◀──────────┘
                                  │ strength│
                                  └────┬────┘
                                       ▼
                                  ┌─────────┐
                                  │ RFC-005 │  reminders (cadence + strength + recency)
                                  └─────────┘
```

**Critical path:** `U0 → RFC-003 (interactions) → RFC-006 (strength) → RFC-005 (reminders)`.
RFC-001, RFC-002, and RFC-004 can proceed in parallel once `U0` lands, because they touch
disjoint files after the shared model change is integrated.

## Shared Foundation Unit (U0) — must merge first

Because every RFC extends the `Contact` model, the model evolution is extracted into a
single foundation unit to avoid parallel agents colliding on `contact.dart`.

- **id:** `U0-model-foundation`
- **depends_on:** []
- **scope:** Add `phone`, `email`, `notes` (String), `interactions` (`List<InteractionEvent>`),
  `reminderCadenceDays` (`int?`) to `Contact`; add `Contact.copyWith(...)`; extend
  `fromJson`/`toJson` with backward-compatible defaults; add `InteractionEvent` model.
- **acceptance_tests:** existing `fromJson` of legacy JSON (no new fields) still parses;
  `copyWith` returns a new instance with only specified fields changed; round-trip
  `toJson→fromJson` is lossless including interactions.
- **risk_level:** Tier 2 (touches the shared model every widget reads).
- **rollback_plan:** revert `contact.dart`; new fields are additive and nullable/defaulted,
  so no data migration needed.

## Merge Queue Rules (applied to every RFC)

1. `U0` merges before any feature unit.
2. Never merge a unit while `flutter analyze` reports errors or its acceptance tests fail.
3. Re-run `flutter analyze` + `flutter test` after each queued merge (integration gate).
4. Shared-file units (touching `contact.dart` / `main.dart`) run **sequentially**;
   disjoint-file units may run in **parallel**.

## Outputs (per ralphinho pipeline)

- RFC execution log (this set + per-RFC unit tables)
- Unit scorecards (acceptance test pass/fail per unit)
- Dependency graph snapshot (above)
- Integration risk summary (per RFC "Risks" section)
