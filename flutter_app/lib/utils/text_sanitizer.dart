/// Unicode replacement character substituted for malformed input.
const int _replacementRune = 0xFFFD;

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Whether [s] is well-formed UTF-16: every high surrogate is immediately
/// followed by a low surrogate and there are no lone low surrogates.
bool isWellFormedUtf16(String s) {
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (_isHighSurrogate(unit)) {
      final next = i + 1 < units.length ? units[i + 1] : 0;
      if (_isLowSurrogate(next)) {
        i++; // Valid pair — skip the low half.
      } else {
        return false; // High surrogate with no following low surrogate.
      }
    } else if (_isLowSurrogate(unit)) {
      return false; // Low surrogate with no preceding high surrogate.
    }
  }
  return true;
}

/// Returns [input] with any malformed UTF-16 (unpaired surrogate code units)
/// replaced by the Unicode replacement character (U+FFFD).
///
/// Device address books occasionally yield strings containing lone surrogate
/// halves (e.g. an emoji truncated by the OS). Such strings crash Flutter text
/// rendering (`addText`: "string is not well-formed UTF-16") and are rejected by
/// Cloud Firestore with `invalid-argument`, because a lone surrogate cannot be
/// encoded as valid UTF-8. Sanitizing at the data boundary keeps both rendering
/// and cloud writes safe. Well-formed input is returned unchanged.
String sanitizeUtf16(String input) {
  if (input.isEmpty || isWellFormedUtf16(input)) return input;
  final units = input.codeUnits;
  final buffer = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (_isHighSurrogate(unit)) {
      final next = i + 1 < units.length ? units[i + 1] : 0;
      if (_isLowSurrogate(next)) {
        buffer.writeCharCode(unit);
        buffer.writeCharCode(next);
        i++;
      } else {
        buffer.writeCharCode(_replacementRune);
      }
    } else if (_isLowSurrogate(unit)) {
      buffer.writeCharCode(_replacementRune);
    } else {
      buffer.writeCharCode(unit);
    }
  }
  return buffer.toString();
}
