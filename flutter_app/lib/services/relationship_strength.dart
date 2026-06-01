import 'dart:math' as math;

import 'package:social_graph/models/contact.dart';

/// Relationship strength scoring (RFC-006, U6.1).
///
/// Pure, deterministic scoring of how "strong" a relationship with a [Contact]
/// is, on a 0..100 scale. No I/O, no clock access — the caller supplies `now`
/// so the function is fully deterministic for a fixed input + `now`.
///
/// ## Weighting (components sum to 100)
///
/// The final score is the sum of four sub-scores, each normalised to its own
/// maximum so the totals add up to exactly 100 at full saturation:
///
/// | Component        | Max points | Behaviour                                  |
/// |------------------|-----------:|--------------------------------------------|
/// | (a) Recency      |         45 | Exponential decay on days since last touch |
/// | (b) Interactions |         30 | log-scaled saturation on count             |
/// | (c) Connections  |         15 | log-scaled saturation on count             |
/// | (d) Close tags   |         10 | fixed boost if a "close" tag is present    |
/// | **Total**        |    **100** |                                            |
///
/// Each component is individually clamped to its own range, and the final sum
/// is clamped to 0..100 as a defensive guarantee.

/// Maximum points contributed by interaction recency.
const double _kRecencyWeight = 45.0;

/// Maximum points contributed by total interaction count.
const double _kInteractionWeight = 30.0;

/// Maximum points contributed by the number of graph connections.
const double _kConnectionWeight = 15.0;

/// Fixed points awarded when a contact carries a "close" tag.
const double _kCloseTagWeight = 10.0;

/// Half-life (in days) of the recency decay. After this many days since the
/// last interaction, the recency component is worth half its maximum.
const double _kRecencyHalfLifeDays = 30.0;

/// Interaction count at which the interaction component effectively saturates.
/// The log scaling means the curve approaches the max asymptotically; this is
/// the count that maps to (near) full points.
const int _kInteractionSaturation = 30;

/// Connection count at which the connection component effectively saturates.
const int _kConnectionSaturation = 15;

/// Tags (case-insensitive) that mark a "close" relationship and earn the boost.
const Set<String> _kCloseTags = {'family', 'friend', 'friends'};

/// Returns a relationship strength score for [c] as of [now], clamped to 0..100.
///
/// Deterministic: the same [c] and [now] always produce the same score.
double strengthScore(Contact c, {required DateTime now}) {
  final recency = _recencyScore(c.lastInteraction, now);
  final interactions = _saturatingScore(
    c.interactions.length,
    _kInteractionSaturation,
    _kInteractionWeight,
  );
  final connections = _saturatingScore(
    c.connections.length,
    _kConnectionSaturation,
    _kConnectionWeight,
  );
  final closeTag = _closeTagScore(c.tags);

  final total = recency + interactions + connections + closeTag;
  return total.clamp(0.0, 100.0);
}

/// (a) Recency: exponential decay based on days since [lastInteraction].
///
/// A `null` last interaction contributes 0. Otherwise the score is
/// `weight * 0.5 ^ (daysSince / halfLife)`, so a brand-new interaction is worth
/// the full weight and it halves every [_kRecencyHalfLifeDays]. Future-dated
/// interactions (negative elapsed days) are treated as "now" (full weight).
double _recencyScore(DateTime? lastInteraction, DateTime now) {
  if (lastInteraction == null) return 0.0;
  final elapsedDays = now.difference(lastInteraction).inSeconds / 86400.0;
  final clampedDays = elapsedDays < 0 ? 0.0 : elapsedDays;
  final decay = math.pow(0.5, clampedDays / _kRecencyHalfLifeDays).toDouble();
  return _kRecencyWeight * decay;
}

/// (b)/(c) Saturating log-scaled score: maps a non-negative [count] onto
/// `0..weight`, rising quickly then flattening, reaching ~[weight] at
/// [saturation]. Uses `log1p` so that count 0 -> 0 points.
double _saturatingScore(int count, int saturation, double weight) {
  if (count <= 0) return 0.0;
  final numerator = math.log(1 + count);
  final denominator = math.log(1 + saturation);
  final fraction = (numerator / denominator).clamp(0.0, 1.0);
  return weight * fraction;
}

/// (d) Close-tag boost: a fixed [_kCloseTagWeight] if any tag (case-insensitive,
/// trimmed) is in [_kCloseTags], otherwise 0.
double _closeTagScore(List<String> tags) {
  for (final tag in tags) {
    if (_kCloseTags.contains(tag.trim().toLowerCase())) {
      return _kCloseTagWeight;
    }
  }
  return 0.0;
}

/// Human-readable band for a strength [score].
///
/// Per the project convention (CLAUDE.md), formatting lives here as a getter
/// rather than inline in widgets:
///   * `score < 33`  -> 'Weak'
///   * `score < 66`  -> 'Moderate'
///   * `score >= 66` -> 'Strong'
String strengthLabel(double score) {
  if (score < 33) return 'Weak';
  if (score < 66) return 'Moderate';
  return 'Strong';
}
