import '../models/contact.dart';

/// Detects likely-duplicate contacts and groups them together.
///
/// Strong signals force-group two contacts regardless of name:
///   - identical non-empty phone number (digits only), or
///   - identical non-empty lowercased email.
///
/// Fuzzy signal groups two contacts when either:
///   - normalized name similarity (Levenshtein ratio) >= [threshold], or
///   - same lowercased workplace AND same lowercased firstName (both non-empty).
///
/// Returns groups of >= 2 contacts each; singletons are omitted. Ordering is
/// deterministic: contacts within a group keep input order, and groups are
/// sorted by the id of their first contact.

/// Keep only digit characters from a phone string.
String _digitsOnly(String phone) {
  final buffer = StringBuffer();
  for (final unit in phone.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}

/// Normalize a name for fuzzy comparison: lowercase, collapse whitespace,
/// strip non-alphanumeric (keeping spaces).
String _normalizeName(Contact c) {
  final raw = c.displayName.toLowerCase();
  final buffer = StringBuffer();
  var lastWasSpace = false;
  for (final rune in raw.runes) {
    final char = String.fromCharCode(rune);
    final isAlphaNum = (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x61 && rune <= 0x7a);
    if (isAlphaNum) {
      buffer.write(char);
      lastWasSpace = false;
    } else if (char == ' ' || char == '\t') {
      if (!lastWasSpace) {
        buffer.write(' ');
        lastWasSpace = true;
      }
    }
    // Drop other punctuation entirely.
  }
  return buffer.toString().trim();
}

/// Classic Levenshtein edit distance between two strings.
int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final deletion = previous[j + 1] + 1;
      final insertion = current[j] + 1;
      final substitution = previous[j] + cost;
      var min = deletion < insertion ? deletion : insertion;
      if (substitution < min) min = substitution;
      current[j + 1] = min;
    }
    final tmp = previous;
    previous = current;
    current = tmp;
  }
  return previous[b.length];
}

/// Normalized Levenshtein similarity ratio in [0.0, 1.0].
/// 1.0 means identical, 0.0 means maximally different.
double nameSimilarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1.0;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1.0;
  final distance = _levenshtein(a, b);
  return 1.0 - (distance / maxLen);
}

/// Decide whether two contacts are likely duplicates.
bool _isMatch(Contact a, Contact b, double threshold) {
  // Strong: phone.
  final phoneA = _digitsOnly(a.phone);
  final phoneB = _digitsOnly(b.phone);
  if (phoneA.isNotEmpty && phoneA == phoneB) return true;

  // Strong: email.
  final emailA = a.email.trim().toLowerCase();
  final emailB = b.email.trim().toLowerCase();
  if (emailA.isNotEmpty && emailA == emailB) return true;

  // Fuzzy: workplace + firstName.
  final workA = a.workplace.trim().toLowerCase();
  final workB = b.workplace.trim().toLowerCase();
  final firstA = a.firstName.trim().toLowerCase();
  final firstB = b.firstName.trim().toLowerCase();
  if (workA.isNotEmpty &&
      workA == workB &&
      firstA.isNotEmpty &&
      firstA == firstB) {
    return true;
  }

  // Fuzzy: name similarity.
  final nameA = _normalizeName(a);
  final nameB = _normalizeName(b);
  if (nameA.isNotEmpty && nameB.isNotEmpty) {
    if (nameSimilarity(nameA, nameB) >= threshold) return true;
  }

  return false;
}

/// Group likely-duplicate contacts via union-find over pairwise matches.
List<List<Contact>> findDuplicateGroups(
  List<Contact> contacts, {
  double threshold = 0.82,
}) {
  final n = contacts.length;
  if (n < 2) return const [];

  // Union-find parent array.
  final parent = List<int>.generate(n, (i) => i);

  int find(int x) {
    var root = x;
    while (parent[root] != root) {
      root = parent[root];
    }
    // Path compression.
    var cur = x;
    while (parent[cur] != root) {
      final next = parent[cur];
      parent[cur] = root;
      cur = next;
    }
    return root;
  }

  void union(int a, int b) {
    final ra = find(a);
    final rb = find(b);
    if (ra == rb) return;
    // Keep the lower index as root for determinism.
    if (ra < rb) {
      parent[rb] = ra;
    } else {
      parent[ra] = rb;
    }
  }

  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      if (_isMatch(contacts[i], contacts[j], threshold)) {
        union(i, j);
      }
    }
  }

  // Collect members per root, preserving input order within each group.
  final groupsByRoot = <int, List<Contact>>{};
  for (var i = 0; i < n; i++) {
    final root = find(i);
    groupsByRoot.putIfAbsent(root, () => <Contact>[]).add(contacts[i]);
  }

  final result = groupsByRoot.values.where((g) => g.length >= 2).toList();

  // Deterministic ordering: by the id of the first contact in each group.
  result.sort((a, b) => a.first.id.compareTo(b.first.id));
  return result;
}
