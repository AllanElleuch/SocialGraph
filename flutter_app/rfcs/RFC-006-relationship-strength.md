# RFC-006 — Relationship Strength Scoring

**Tier:** P2 (differentiator) · **Priority:** 6
**Depends on:** `U0-model-foundation`, RFC-003 (interactions)

## Summary

Rank closeness per contact. Strength ties together interaction frequency/recency, number
of mutual connections, and tags into a single 0–100 score that powers RFC-005 prioritization
and weights the GraphView edges/nodes. Makes the network *intelligent*, not just visual.

## Work Units

### U6.1 — Strength scoring engine
- **id:** `U6.1-strength-engine`
- **depends_on:** [`U0-model-foundation`, `U3.1-interaction-model`]
- **scope:** `lib/services/relationship_strength.dart` — pure
  `strengthScore(Contact, {now}) → double (0–100)` combining: recency of `lastInteraction`
  (decay), interaction count, `connections.length`, and a small tag boost. Documented,
  weighted, deterministic. Add `Contact.strengthLabel` getter (Weak/Moderate/Strong) per
  CLAUDE.md formatting convention (getter on the model/VM, not inline in widgets).
- **acceptance_tests:** recent + frequent + well-connected scores higher than a stale
  isolated contact; score is bounded 0–100; deterministic for fixed input/now.
- **risk_level:** Tier 1 (pure logic).
- **rollback_plan:** delete the service + getter; no dependents break if unused.

### U6.2 — Strength in ContactCard
- **id:** `U6.2-strength-ui`
- **depends_on:** [`U6.1-strength-engine`]
- **scope:** Show a strength meter/label on the card using the `strengthLabel` getter and a
  bar. No inline formatting in the widget.
- **acceptance_tests:** card shows the correct band for known fixtures; updates after an
  interaction is logged.
- **risk_level:** Tier 1.
- **rollback_plan:** revert card section.

### U6.3 — Graph weighting
- **id:** `U6.3-graph-weight`
- **depends_on:** [`U6.1-strength-engine`]
- **scope:** Use strength to scale node radius / edge emphasis in `graph_painter.dart` /
  `force_simulation.dart` (stronger ties drawn larger / pulled closer).
- **acceptance_tests:** higher-strength contacts render with larger nodes; simulation stays
  stable (no NaN / runaway forces).
- **risk_level:** Tier 2 (touches the physics simulation).
- **rollback_plan:** revert painter/sim changes; scoring + card remain.

## Risks / Integration
- Consumes RFC-003 interaction data — merge after RFC-003.
- Feeds RFC-005 sort order — expose `strengthScore` before RFC-005 U5.2.
- Graph physics change (U6.3) is the riskiest; ship behind a constant weight factor that
  defaults to current behavior.

## Outputs
- `relationship_strength.dart`, strength meter UI, graph weighting, unit tests for scoring
  bounds + monotonicity.
